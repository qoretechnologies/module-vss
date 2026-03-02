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
/** Enables navigating the VSS tree: Vehicle → Cabin → Door → Row1 → ...
    Branch nodes support children navigation; leaf nodes support request for
    signal metadata retrieval.
*/
public class VssCatalogDataProvider inherits DataProvider::AbstractDataProvider {
    private {
        #! The VSS tree
        VssLoader::VssTree tree;

        #! Current path in the tree (NOTHING for root)
        *string current_path;
    }

    #! Creates a root catalog provider
    constructor(VssLoader::VssTree tree) {
        self.tree = tree;
    }

    #! Creates a sub-path catalog provider
    constructor(VssLoader::VssTree tree, string path) {
        self.tree = tree;
        self.current_path = path;
    }

    #! Returns the provider name
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

    #! Returns provider description
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
        };
    }
}

} # namespace VssDataProvider
