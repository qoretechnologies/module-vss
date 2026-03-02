# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssRootDataProvider.qc VSS root data provider

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

#! Root VSS data provider with children \c "catalog" and \c "validate"
/** Entry point for browsing VSS signal catalogs and validating telemetry data through
    the DataProvider framework. Loads a VSS catalog from a JSON, YAML, or native .vspec
    file and exposes two child providers:

    - \c "catalog" — a browsable tree of VSS branches and signals
      (@ref VssCatalogDataProvider)
    - \c "validate" — a request-response provider for signal value validation
      (@ref VssValidationDataProvider)

    @par Fleet Telematics Example
    @code{.py}
    # Load the COVESA VSS catalog for a fleet management platform
    VssRootDataProvider root({"catalog_path": "/opt/fleet/vss_rel_4.0.yaml"});

    # Browse the catalog to discover available signals under Vehicle.Chassis
    AbstractDataProvider chassis = root.getChildProvider("catalog")
        .getChildProvider("Vehicle").getChildProvider("Chassis");
    *list<string> children = chassis.getChildProviderNames();
    # ("Accelerator", "Brake", "SteeringWheel", ...)

    # Validate incoming OBD-II speed reading
    AbstractDataProvider validator = root.getChildProvider("validate");
    hash<auto> result = validator.doRequest({
        "path": "Vehicle.Speed",
        "value": 85,
    });
    printf("Valid: %y\n", result.valid); # Valid: True
    @endcode
*/
public class VssRootDataProvider inherits DataProvider::AbstractDataProvider {
    public {
        #! Provider information
        const ProviderInfo = <DataProviderInfo>{
            "name": "vss",
            "desc": "COVESA Vehicle Signal Specification (VSS) catalog data provider.\n\n"
                "Provides browsable tree navigation of VSS signal catalogs and data "
                "validation against VSS signal definitions",
            "type": "VssRootDataProvider",
            "supports_children": True,
            "children_can_support_apis": True,
            "constructor_options": ConstructorOptions,
        };

        #! Constructor option metadata
        const ConstructorOptions = {
            "catalog_path": <DataProviderOptionInfo>{
                "display_name": "Catalog Path",
                "short_desc": "Path to VSS catalog file",
                "type": AbstractDataProviderTypeMap."string",
                "desc": "Path to the VSS catalog file. Supported formats:\n"
                    "- `.json` — pre-exported VSS JSON catalog\n"
                    "- `.yaml` / `.yml` — pre-exported VSS YAML catalog\n"
                    "- `.vspec` — native VSS specification file with `#include` support",
                "required": True,
                "example_value": "/path/to/vss_v6.yaml",
            },
            "vss_version": <DataProviderOptionInfo>{
                "display_name": "VSS Version",
                "short_desc": "VSS specification version",
                "type": AbstractDataProviderTypeMap."*string",
                "desc": "Version of the VSS specification (informational only)",
                "default_value": "unknown",
            },
        };
    }

    private {
        #! The loaded VSS tree
        VssLoader::VssTree tree;
    }

    #! Creates the root provider from options
    /** @param options hash containing "catalog_path" and optionally "vss_version"

        @throw VSS-PROVIDER-ERROR if catalog_path is not provided
    */
    constructor(hash<auto> options) {
        if (!exists options.catalog_path) {
            throw "VSS-PROVIDER-ERROR", "option 'catalog_path' is required";
        }
        tree = new VssLoader::VssTree(string(options.catalog_path));
    }

    #! Returns the provider name
    /** @return \c "vss"
    */
    string getName() {
        return "vss";
    }

    #! Returns a human-readable provider description
    /** @return the provider description string
    */
    *string getDesc() {
        return "COVESA Vehicle Signal Specification (VSS) catalog data provider";
    }

    #! Returns the list of child provider names
    private *list<string> getChildProviderNamesImpl() {
        return ("catalog", "validate");
    }

    #! Returns a child provider by name
    private *DataProvider::AbstractDataProvider getChildProviderImpl(string name) {
        switch (name) {
            case "catalog":
                return new VssCatalogDataProvider(tree);
            case "validate":
                return new VssValidationDataProvider(tree);
        }
        return NOTHING;
    }

    #! Returns provider static info
    private hash<DataProvider::DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

} # namespace VssDataProvider
