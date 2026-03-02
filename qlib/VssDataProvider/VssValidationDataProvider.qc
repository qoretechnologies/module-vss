# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssValidationDataProvider.qc VSS validation data provider

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

#! Request-response data provider for VSS validation
/** Accepts a hash with \c "path" (VSS signal path) and \c "value" (value to validate),
    returns a hash with \c "valid" (bool) and \c "errors" (list of validation errors).

    Performs type checking, range validation, and allowed-value enumeration checking
    against the VSS catalog definitions.

    @par Fleet Data Quality Gate Example
    @code{.py}
    # Validate incoming telemetry before persisting to fleet database
    AbstractDataProvider validator = root.getChildProvider("validate");

    # Valid reading — coolant temperature within uint8 range
    hash<auto> ok = validator.doRequest({
        "path": "Vehicle.Powertrain.CombustionEngine.ECT",
        "value": 95,
    });
    printf("Valid: %y\n", ok.valid); # True

    # Invalid reading — fuel level exceeds 100 percent
    hash<auto> bad = validator.doRequest({
        "path": "Vehicle.Powertrain.FuelSystem.Level",
        "value": 150,
    });
    printf("Valid: %y, Error: %s\n", bad.valid, bad.errors[0].message);
    # Valid: False, Error: value 150 above node maximum 100
    @endcode
*/
public class VssValidationDataProvider inherits DataProvider::AbstractDataProvider {
    public {
        #! Request type
        static VssValidationRequestDataType RequestType();

        #! Response type
        static VssValidationResponseDataType ResponseType();
    }

    private {
        #! The VSS tree
        VssLoader::VssTree tree;

        #! Validator
        VssLoader::VssValidator validator;
    }

    #! Creates a validation provider backed by the given VSS tree
    /** @param tree the loaded VSS tree containing signal definitions for validation
    */
    constructor(VssLoader::VssTree tree) {
        self.tree = tree;
        self.validator = new VssLoader::VssValidator(tree);
    }

    #! Returns the provider name
    /** @return \c "validate"
    */
    string getName() {
        return "validate";
    }

    #! Returns a human-readable provider description
    /** @return the description string
    */
    *string getDesc() {
        return "Validate signal values against VSS catalog definitions";
    }

    #! Handles validation request
    /** @param req hash with `path` (string) and `value` (auto) keys

        @return hash with `valid` (bool) and `errors` (list) keys
    */
    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        if (req.typeCode() != NT_HASH) {
            throw "VSS-VALIDATION-ERROR", "request must be a hash with 'path' and 'value' keys";
        }

        hash<auto> request = req;
        if (!exists request.path) {
            throw "VSS-VALIDATION-ERROR", "request must contain 'path' key";
        }

        list<hash<VssLoader::VssValidationError>> errors = validator.validateValue(
            string(request.path), request.value);

        return {
            "valid": errors.empty(),
            "errors": errors,
        };
    }

    #! Returns the request type
    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return RequestType;
    }

    #! Returns the response type
    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return ResponseType;
    }

    #! Returns provider static info
    private hash<DataProvider::DataProviderInfo> getStaticInfoImpl() {
        return <DataProviderInfo>{
            "name": "validate",
            "desc": "Validate signal values against VSS catalog definitions",
            "type": "VssValidationDataProvider",
            "supports_request": True,
        };
    }
}

} # namespace VssDataProvider
