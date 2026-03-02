# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssCatalogDataProvider.qc Browsable VSS catalog tree

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

#! Browsable VSS catalog data provider
/** Enables navigating the VSS signal tree hierarchically:
    Vehicle → Cabin → Door → Row1 → ...

    Branch nodes support children navigation; leaf nodes (sensors, actuators, attributes)
    are represented as @ref VssSignalDataProvider instances that return signal metadata
    via the request API.

    @par Fleet Signal Discovery Example
    @code{.py}
    # Discover all available powertrain signals for a fleet diagnostics dashboard
    AbstractDataProvider powertrain = root.getChildProvider("catalog")
        .getChildProvider("Vehicle").getChildProvider("Powertrain");
    *list<string> children = powertrain.getChildProviderNames();
    # ("CombustionEngine", "ElectricMotor", "FuelSystem", "Transmission", ...)

    # Drill into a specific signal to get its metadata
    AbstractDataProvider rpm = powertrain.getChildProvider("CombustionEngine")
        .getChildProvider("Speed");
    hash<auto> meta = rpm.doRequest({});
    printf("Engine RPM: type=%s, unit=%s, max=%y\n", meta.datatype, meta.unit, meta.max);
    # Engine RPM: type=uint16, unit=rpm, max=20000
    @endcode
*/
public class VssCatalogDataProvider inherits DataProvider::AbstractDataProvider {
    private {
        #! The VSS tree
        VssLoader::VssTree tree;

        #! Current path in the tree (NOTHING for root)
        *string current_path;
    }

    #! Creates a root catalog provider
    /** @param tree the loaded VSS tree to browse
    */
    constructor(VssLoader::VssTree tree) {
        self.tree = tree;
    }

    #! Creates a sub-path catalog provider for a specific branch
    /** @param tree the loaded VSS tree to browse
        @param path the current branch path in the tree (e.g. \c "Vehicle.Chassis")
    */
    constructor(VssLoader::VssTree tree, string path) {
        self.tree = tree;
        self.current_path = path;
    }

    #! Returns the provider name (leaf segment of the current path, or \c "catalog" for root)
    /** @return the name string
    */
    string getName() {
        if (exists current_path) {
            # return the last segment
            int dot = current_path.rfind(".");
            if (dot >= 0) {
                return current_path.substr(dot + 1);
            }
            return current_path;
        }
        return "catalog";
    }

    #! Returns the VSS node description for the current path, or a default for root
    /** @return the description string, or \c "VSS catalog browser" at root level
    */
    *string getDesc() {
        if (exists current_path) {
            *hash<VssLoader::VssNode> node = tree.getNode(current_path);
            if (exists node) {
                return node.description;
            }
        }
        return "VSS catalog browser";
    }

    #! Returns the list of child provider names
    private *list<string> getChildProviderNamesImpl() {
        list<string> children = tree.getChildNames(current_path);
        if (children.size()) {
            return children;
        }
        return NOTHING;
    }

    #! Returns a child provider by name
    private *DataProvider::AbstractDataProvider getChildProviderImpl(string name) {
        string child_path = exists current_path ? current_path + "." + name : name;
        if (tree.hasPath(child_path)) {
            *hash<VssLoader::VssNode> node = tree.getNode(child_path);
            if (exists node && node.type != VssLoader::VssNodeType_BRANCH) {
                # leaf node - return signal provider
                return new VssSignalDataProvider(tree, child_path);
            }
            # branch node - return catalog sub-tree
            return new VssCatalogDataProvider(tree, child_path);
        }
        return NOTHING;
    }

    #! Returns provider static info
    private hash<DataProvider::DataProviderInfo> getStaticInfoImpl() {
        return <DataProviderInfo>{
            "name": getName(),
            "desc": getDesc(),
            "type": "VssCatalogDataProvider",
            "supports_children": True,
            "children_can_support_apis": True,
        };
    }
}

} # namespace VssDataProvider
