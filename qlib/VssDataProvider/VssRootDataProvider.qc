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

#! Root VSS data provider with children "catalog" and "validate"
public class VssRootDataProvider inherits DataProvider::AbstractDataProvider {
    public {
        #! Provider information
        const ProviderInfo = <DataProviderInfo>{
            "name": "vss",
            "desc": "COVESA VSS catalog data provider",
            "type": "VssRootDataProvider",
            "supports_children": True,
            "constructor_options": ConstructorOptions,
        };

        #! Constructor option metadata
        const ConstructorOptions = {
            "catalog_path": <DataProviderOptionInfo>{
                "display_name": "Catalog Path",
                "short_desc": "Path to VSS catalog file",
                "type": AbstractDataProviderTypeMap."string",
                "desc": "Path to the VSS catalog file (JSON, YAML, or .vspec format)",
                "required": True,
                "example_value": "/path/to/vss_v6.yaml",
            },
            "vss_version": <DataProviderOptionInfo>{
                "display_name": "VSS Version",
                "short_desc": "VSS specification version",
                "type": AbstractDataProviderTypeMap."string",
                "desc": "Version of the VSS specification (informational)",
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
    string getName() {
        return "vss";
    }

    #! Returns provider description
    *string getDesc() {
        return "COVESA VSS catalog data provider";
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
