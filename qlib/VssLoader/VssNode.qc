# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssNode.qc VSS node type definitions

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

#! Represents a single VSS signal or branch node
public hashdecl VssNode {
    #! Leaf segment of path (e.g. "Speed" for "Vehicle.Speed")
    string name;

    #! Full dot-separated path (e.g. "Vehicle.Speed")
    string path;

    #! Node type: "branch", "sensor", "actuator", "attribute"
    string type;

    #! VSS datatype for leaf nodes (e.g. "uint16", "float", "boolean", "string")
    *string datatype;

    #! Human-readable description of this node
    string description;

    #! Unit of measurement (e.g. "km/h", "celsius", "percent")
    *string unit;

    #! Minimum allowed value
    *float min;

    #! Maximum allowed value
    *float max;

    #! Enumerated list of allowed values
    *list<auto> allowed;

    #! Default value for this signal
    *auto default_value;

    #! Comment or additional notes
    *string comment;

    #! Deprecation notice (if the signal is deprecated)
    *string deprecation;

    #! Instance specification for branch nodes (list or range notation)
    *auto instances;

    #! Overlay delete marker
    *bool is_delete;

    #! Non-standard/OEM metadata (e.g. dbc block, custom extensions)
    *hash<string, auto> custom;
}

#! Represents a validation error for a VSS signal value
public hashdecl VssValidationError {
    #! VSS path that was validated
    string path;

    #! Error type: "TYPE_MISMATCH", "RANGE_VIOLATION", "ENUM_VIOLATION",
    #! "UNKNOWN_PATH", "ARRAY_SIZE_MISMATCH"
    string error_type;

    #! Human-readable error message
    string message;

    #! The actual value that failed validation
    auto actual_value;
}

#! Represents a unit conversion specification
public hashdecl VssUnitConversion {
    #! Source unit
    string from_unit;

    #! Target unit
    string to_unit;

    #! Multiplication factor: target = source * factor + offset
    float factor;

    #! Additive offset: target = source * factor + offset
    float offset;
}

} # namespace VssLoader
