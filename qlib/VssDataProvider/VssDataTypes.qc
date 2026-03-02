# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssDataTypes.qc VSS data provider request and response types

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

public namespace VssDataProvider {

#! Response type for VSS signal metadata requests
/** Describes the structure of signal metadata returned by @ref VssSignalDataProvider when
    querying a leaf signal node. Used in fleet management systems to discover signal
    properties before processing telemetry data.

    @par Example
    @code{.py}
    # Query vehicle speed signal metadata for fleet dashboard configuration
    AbstractDataProvider speed = provider.getChildProvider("catalog")
        .getChildProvider("Vehicle").getChildProvider("Speed");
    hash<auto> meta = speed.doRequest({});
    # meta = {"path": "Vehicle.Speed", "type": "sensor", "datatype": "float",
    #          "unit": "km/h", "min": 0, "max": 600, ...}
    @endcode
*/
public class VssSignalResponseDataType inherits DataProvider::HashDataType {
    public {
        #! Field definitions
        const Fields = {
            "path": {
                "type": AbstractDataProviderTypeMap."string",
                "display_name": "Path",
                "short_desc": "Full VSS dot-separated path",
                "desc": "Full dot-separated VSS path (e.g., `Vehicle.Speed`)",
                "example_value": "Vehicle.Speed",
            },
            "name": {
                "type": AbstractDataProviderTypeMap."string",
                "display_name": "Name",
                "short_desc": "Leaf segment of the signal path",
                "desc": "Leaf segment of the signal path (e.g., `Speed`)",
                "example_value": "Speed",
            },
            "type": {
                "type": AbstractDataProviderTypeMap."string",
                "display_name": "Type",
                "short_desc": "VSS node type",
                "desc": "VSS node type: `sensor`, `actuator`, or `attribute`",
                "example_value": "sensor",
            },
            "datatype": {
                "type": AbstractDataProviderTypeMap."*string",
                "display_name": "Datatype",
                "short_desc": "VSS datatype",
                "desc": "VSS datatype (e.g., `uint8`, `float`, `boolean`, `string`)",
                "example_value": "float",
            },
            "description": {
                "type": AbstractDataProviderTypeMap."string",
                "display_name": "Description",
                "short_desc": "Signal description",
                "desc": "Human-readable description of the signal",
            },
            "unit": {
                "type": AbstractDataProviderTypeMap."*string",
                "display_name": "Unit",
                "short_desc": "Unit of measurement",
                "desc": "Unit of measurement (e.g., `km/h`, `celsius`, `percent`)",
                "example_value": "km/h",
            },
            "min": {
                "type": AbstractDataProviderTypeMap."*float",
                "display_name": "Min",
                "short_desc": "Minimum allowed value",
                "desc": "Minimum allowed value for this signal",
            },
            "max": {
                "type": AbstractDataProviderTypeMap."*float",
                "display_name": "Max",
                "short_desc": "Maximum allowed value",
                "desc": "Maximum allowed value for this signal",
            },
            "allowed": {
                "type": AbstractDataProviderTypeMap."*softlist",
                "display_name": "Allowed Values",
                "short_desc": "Enumerated allowed values",
                "desc": "List of allowed values for this signal (if constrained)",
            },
            "default_value": {
                "type": AbstractDataProviderTypeMap."auto",
                "display_name": "Default Value",
                "short_desc": "Default signal value",
                "desc": "Default value for this signal",
            },
            "deprecation": {
                "type": AbstractDataProviderTypeMap."*string",
                "display_name": "Deprecation",
                "short_desc": "Deprecation notice",
                "desc": "Deprecation notice if the signal is deprecated",
            },
        };
    }

    #! Creates the type and registers all signal metadata fields
    constructor() {
        addQoreFields(Fields);
    }
}

#! Request type for VSS validation
/** Describes the request structure for @ref VssValidationDataProvider. Clients submit a
    VSS signal path and value for validation against the catalog definition.

    @par Example
    @code{.py}
    # Validate an engine coolant temperature reading from a fleet vehicle
    hash<auto> result = validator.doRequest({
        "path": "Vehicle.Powertrain.CombustionEngine.ECT",
        "value": 95,
    });
    @endcode
*/
public class VssValidationRequestDataType inherits DataProvider::HashDataType {
    public {
        #! Field definitions
        const Fields = {
            "path": {
                "type": AbstractDataProviderTypeMap."string",
                "display_name": "VSS Path",
                "short_desc": "VSS signal path to validate against",
                "desc": "Full dot-separated VSS path (e.g., `Vehicle.Speed`)",
                "example_value": "Vehicle.Speed",
            },
            "value": {
                "type": AbstractDataProviderTypeMap."auto",
                "display_name": "Value",
                "short_desc": "Value to validate",
                "desc": "The value to validate against the VSS signal definition",
                "example_value": 100.0,
            },
        };
    }

    #! Creates the type and registers the validation request fields
    constructor() {
        addQoreFields(Fields);
    }
}

#! Response type for VSS validation
/** Describes the validation response returned by @ref VssValidationDataProvider.
    Contains a boolean validity flag and a list of validation errors (empty when valid).

    @par Example
    @code{.py}
    hash<auto> result = validator.doRequest({
        "path": "Vehicle.Speed",
        "value": 999,
    });
    # result.valid = False
    # result.errors = ({"path": "Vehicle.Speed", "error_type": "RANGE_VIOLATION", ...})
    @endcode
*/
public class VssValidationResponseDataType inherits DataProvider::HashDataType {
    public {
        #! Field definitions
        const Fields = {
            "valid": {
                "type": AbstractDataProviderTypeMap."bool",
                "display_name": "Valid",
                "short_desc": "Whether the value passed validation",
                "desc": "`True` if the value is valid according to the VSS signal definition",
            },
            "errors": {
                "type": AbstractDataProviderTypeMap."softlist",
                "display_name": "Errors",
                "short_desc": "List of validation errors",
                "desc": "List of validation error hashes; empty if the value is valid. "
                    "Each error has `path`, `error_type`, `message`, and `actual_value` keys",
            },
        };
    }

    #! Creates the type and registers the validation response fields
    constructor() {
        addQoreFields(Fields);
    }
}

} # namespace VssDataProvider
