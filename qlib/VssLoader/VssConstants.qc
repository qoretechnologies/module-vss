# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssConstants.qc VSS type system constants

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

#! VSS node type enumeration
public const VssNodeType_BRANCH = "branch";
public const VssNodeType_SENSOR = "sensor";
public const VssNodeType_ACTUATOR = "actuator";
public const VssNodeType_ATTRIBUTE = "attribute";

#! Valid VSS node type set (for O(1) membership testing during parsing)
public const VssValidNodeTypes = {
    "branch": True,
    "sensor": True,
    "actuator": True,
    "attribute": True,
};

#! VSS datatype to Qore type mapping
public const VssToQoreTypeMap = {
    "uint8": "int",
    "int8": "int",
    "uint16": "int",
    "int16": "int",
    "uint32": "int",
    "int32": "int",
    "uint64": "int",
    "int64": "int",
    "float": "float",
    "double": "float",
    "boolean": "bool",
    "string": "string",
    "string[]": "list",
    "uint8[]": "list",
    "int32[]": "list",
    "float[]": "list",
    "double[]": "list",
    "boolean[]": "list",
    "iso8601": "string",
    "numeric": "number",
};

#! VSS type intrinsic ranges (min, max)
public const VssTypeRanges = {
    "uint8": {"min": 0, "max": 255},
    "int8": {"min": -128, "max": 127},
    "uint16": {"min": 0, "max": 65535},
    "int16": {"min": -32768, "max": 32767},
    "uint32": {"min": 0, "max": 4294967295},
    "int32": {"min": -2147483648, "max": 2147483647},
    "uint64": {"min": 0, "max": 18446744073709551615n},
    "int64": {"min": -9223372036854775808n, "max": 9223372036854775807n},
};

#! Standard VSS node property keys; any other keys are treated as custom/OEM metadata
public const VssStandardNodeKeys = {
    "type": True, "datatype": True, "description": True, "unit": True,
    "min": True, "max": True, "allowed": True, "default": True,
    "comment": True, "deprecation": True, "instances": True, "delete": True,
    "children": True,
};

#! Regex for \c "#include" directive: \c "#include <path> [<mount-point>]"
public const VSS_INCLUDE_REGEX = "^#include\\s+(\\S+)(?:\\s+(\\S+))?\\s*$";

} # namespace VssLoader
