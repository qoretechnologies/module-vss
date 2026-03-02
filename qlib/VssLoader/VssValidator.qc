# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssValidator.qc VSS signal data validator

/*  Copyright (C) 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

public namespace VssLoader {

#! Validates signal data against a VSS catalog
/** Performs type checking, range checking, and enum validation against
    the VSS signal definitions in a VssTree.
*/
public class VssValidator {
    private {
        #! The VSS tree to validate against
        VssTree tree;
    }

    #! Creates a validator for the given VSS tree
    /** @param tree the VSS tree containing signal definitions
    */
    constructor(VssTree tree) {
        self.tree = tree;
    }

    #! Validates a single signal value against its VSS definition
    /** @param vss_path the full VSS path (e.g. "Vehicle.Speed")
        @param value the value to validate

        @return list of validation errors (empty if valid)
    */
    list<hash<VssValidationError>> validateValue(string vss_path, auto value) {
        list<hash<VssValidationError>> errors = ();

        *hash<VssNode> node = tree.getNode(vss_path);
        if (!exists node) {
            push errors, <VssValidationError>{
                "path": vss_path,
                "error_type": "UNKNOWN_PATH",
                "message": sprintf("path %y not found in VSS catalog", vss_path),
                "actual_value": value,
            };
            return errors;
        }

        # skip validation for branch nodes
        if (node.type == VssNodeType_BRANCH) {
            return errors;
        }

        # skip validation for NOTHING values
        if (!exists value) {
            return errors;
        }

        # type validation
        *hash<VssValidationError> type_err = validateType(node, value);
        if (exists type_err) {
            push errors, type_err;
            # if type is wrong, skip further validation
            return errors;
        }

        # range validation
        *hash<VssValidationError> range_err = validateRange(node, value);
        if (exists range_err) {
            push errors, range_err;
        }

        # enum validation
        *hash<VssValidationError> enum_err = validateAllowed(node, value);
        if (exists enum_err) {
            push errors, enum_err;
        }

        return errors;
    }

    #! Validates a record (hash of {vss_path: value})
    /** @param record hash mapping VSS paths to values

        @return list of all validation errors across all fields (empty if valid)
    */
    list<hash<VssValidationError>> validateRecord(hash<auto> record) {
        list<hash<VssValidationError>> errors = ();

        HashIterator it(record);
        while (it.next()) {
            errors += validateValue(it.getKey(), it.getValue());
        }

        return errors;
    }

    #! Validates the Qore type of a value against the VSS datatype
    private *hash<VssValidationError> validateType(hash<VssNode> node, auto value) {
        if (!exists node.datatype) {
            return NOTHING;
        }

        *string expected_qore_type = VssToQoreTypeMap{node.datatype};
        if (!exists expected_qore_type) {
            # unknown VSS datatype - skip type validation
            return NOTHING;
        }

        bool valid;
        switch (expected_qore_type) {
            case "int": {
                valid = value.typeCode() == NT_INT;
                # also accept float with integer value
                if (!valid && value.typeCode() == NT_FLOAT) {
                    valid = value == int(value);
                }
                break;
            }
            case "float": {
                valid = value.typeCode() == NT_FLOAT || value.typeCode() == NT_INT
                    || value.typeCode() == NT_NUMBER;
                break;
            }
            case "bool": {
                valid = value.typeCode() == NT_BOOLEAN;
                break;
            }
            case "string": {
                valid = value.typeCode() == NT_STRING;
                break;
            }
            case "list": {
                valid = value.typeCode() == NT_LIST;
                break;
            }
            case "number": {
                valid = value.typeCode() == NT_NUMBER || value.typeCode() == NT_INT
                    || value.typeCode() == NT_FLOAT;
                break;
            }
            default:
                return NOTHING;
        }

        if (!valid) {
            return <VssValidationError>{
                "path": node.path,
                "error_type": "TYPE_MISMATCH",
                "message": sprintf("expected Qore type %y (VSS %y) but got %y",
                    expected_qore_type, node.datatype, value.type()),
                "actual_value": value,
            };
        }

        return NOTHING;
    }

    #! Validates a numeric value against range constraints
    private *hash<VssValidationError> validateRange(hash<VssNode> node, auto value) {
        # only validate numeric values
        if (value.typeCode() != NT_INT && value.typeCode() != NT_FLOAT
            && value.typeCode() != NT_NUMBER) {
            return NOTHING;
        }

        float fval = float(value);

        # check VSS type intrinsic range
        if (exists node.datatype) {
            *hash<auto> type_range = VssTypeRanges{node.datatype};
            if (exists type_range) {
                if (fval < type_range.min || fval > type_range.max) {
                    return <VssValidationError>{
                        "path": node.path,
                        "error_type": "RANGE_VIOLATION",
                        "message": sprintf("value %y outside type %y range [%y, %y]",
                            value, node.datatype, type_range.min, type_range.max),
                        "actual_value": value,
                    };
                }
            }
        }

        # check node-specific min/max
        if (exists node.min && fval < node.min) {
            return <VssValidationError>{
                "path": node.path,
                "error_type": "RANGE_VIOLATION",
                "message": sprintf("value %y below node minimum %y", value, node.min),
                "actual_value": value,
            };
        }
        if (exists node.max && fval > node.max) {
            return <VssValidationError>{
                "path": node.path,
                "error_type": "RANGE_VIOLATION",
                "message": sprintf("value %y above node maximum %y", value, node.max),
                "actual_value": value,
            };
        }

        return NOTHING;
    }

    #! Validates a value against the allowed values list
    private *hash<VssValidationError> validateAllowed(hash<VssNode> node, auto value) {
        if (!exists node.allowed) {
            return NOTHING;
        }

        bool found = False;
        foreach auto allowed_val in (node.allowed) {
            if (value == allowed_val) {
                found = True;
                break;
            }
        }

        if (!found) {
            return <VssValidationError>{
                "path": node.path,
                "error_type": "ENUM_VIOLATION",
                "message": sprintf("value %y not in allowed values %y", value, node.allowed),
                "actual_value": value,
            };
        }

        return NOTHING;
    }
}

} # namespace VssLoader
