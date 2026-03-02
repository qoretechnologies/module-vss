# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssTree.qc Resolved VSS signal tree

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

#! Represents a resolved VSS signal tree
/** Provides navigation and query operations over a flat map of VSS paths to nodes.
    This is the core data structure for working with VSS catalogs, used by both the
    DataProvider layer and the validation/processing pipeline.

    Can be constructed from:
    - A pre-exported JSON or YAML file
    - A pre-parsed node map (from VssVspecParser)

    @par Fleet Catalog Loading Example
    @code{.py}
    # Load the COVESA VSS v4.0 catalog for a fleet management platform
    VssTree tree("/opt/fleet/catalogs/vss_rel_4.0.yaml");
    printf("Loaded %d signals\n", tree.size());  # Loaded 1247 signals

    # Look up a specific signal
    *hash<VssNode> speed = tree.getNode("Vehicle.Speed");
    printf("Unit: %s, Range: [%y, %y]\n", speed.unit, speed.min, speed.max);

    # Discover children under a branch
    list<string> powertrain_children = tree.getChildNames("Vehicle.Powertrain");
    # ("CombustionEngine", "ElectricMotor", "FuelSystem", "Transmission", ...)

    # Find all tire-related signals using glob matching
    list<string> tire_signals = tree.findPaths("Vehicle.Chassis.Axle.**.Tire.*");
    @endcode
*/
public class VssTree {
    private {
        #! Flat path-to-node map
        hash<string, hash<VssNode>> nodes;

        #! VSS specification version
        string vss_version;

        #! Children index: parent path -> list of direct child names
        #! Empty string key "" holds top-level node names
        hash<string, list<string>> children_index;
    }

    #! Creates a VssTree from a pre-exported JSON or YAML file
    /** @param filepath path to the file (.json, .yaml, .yml, or .vspec)

        @throw VSS-LOAD-ERROR thrown when the file format is unsupported or parsing fails
    */
    constructor(string filepath) {
        auto parsed;
        if (filepath =~ /\.json$/i) {
%ifdef NoJson
            throw "JSON-MODULE-MISSING", "cannot parse JSON file; the json module is not available";
%else
            string content = ReadOnlyFile::readTextFile(filepath);
            try {
                parsed = parse_json(content);
            } catch (hash<ExceptionInfo> ex) {
                throw "VSS-LOAD-ERROR", sprintf("failed to parse JSON file %y: %s", filepath, ex.desc), ex;
            }
%endif
        } else if (filepath =~ /\.(yaml|yml)$/i) {
%ifdef NoYaml
            throw "YAML-MODULE-MISSING", "cannot parse YAML file; the yaml module is not available";
%else
            string content = ReadOnlyFile::readTextFile(filepath);
            try {
                parsed = parse_yaml(content);
            } catch (hash<ExceptionInfo> ex) {
                throw "VSS-LOAD-ERROR", sprintf("failed to parse YAML file %y: %s", filepath, ex.desc), ex;
            }
%endif
        } else if (filepath =~ /\.vspec$/i) {
            VssVspecParser parser(dirname(filepath));
            nodes = parser.parseFile(basename(filepath));
            vss_version = "unknown";
            buildChildrenIndex();
            return;
        } else {
            throw "VSS-LOAD-ERROR",
                sprintf("unsupported file format for %y; expected .json, .yaml, .yml, or .vspec", filepath);
        }

        if (parsed.typeCode() != NT_HASH) {
            throw "VSS-LOAD-ERROR", sprintf("expected hash at top level, got type %y", parsed.type());
        }

        # convert raw hash to VssNode map
        nodes = {};
        loadFromHash(parsed);
        vss_version = "unknown";
        buildChildrenIndex();
    }

    #! Creates a VssTree from a pre-parsed node map
    /** @param nodes flat map of VSS path to VssNode
        @param version the VSS specification version (optional)
    */
    constructor(hash<string, hash<VssNode>> nodes, *string version) {
        self.nodes = nodes;
        vss_version = version ?? "unknown";
        buildChildrenIndex();
    }

    #! Returns the node at the given path, or NOTHING if not found
    *hash<VssNode> getNode(string path) {
        return nodes{path};
    }

    #! Returns True if the given path exists in the tree
    bool hasPath(string path) {
        return exists nodes{path};
    }

    #! Returns the names of direct children of the given branch
    /** @param parent_path the parent path; if NOTHING, returns top-level names

        @return list of child node names (leaf segments)
    */
    list<string> getChildNames(*string parent_path) {
        string key = parent_path ?? "";
        return children_index{key} ?? ();
    }

    #! Returns the child nodes of the given branch
    /** @param branch_path the branch path

        @return list of direct child VssNode hashes
    */
    list<hash<VssNode>> getChildren(string branch_path) {
        list<string> child_names = children_index{branch_path} ?? ();
        list<hash<VssNode>> result = ();
        foreach string name in (child_names) {
            string child_path = branch_path + "." + name;
            if (exists nodes{child_path}) {
                push result, nodes{child_path};
            }
        }
        return result;
    }

    #! Returns all leaf nodes (non-branch nodes)
    list<hash<VssNode>> getLeafNodes() {
        list<hash<VssNode>> result = ();

        HashIterator it(nodes);
        while (it.next()) {
            hash<VssNode> node = it.getValue();
            if (node.type != VssNodeType_BRANCH) {
                push result, node;
            }
        }

        return result;
    }

    #! Finds all paths matching a glob-like pattern
    /** @param glob_pattern pattern with * (one segment) and ** (any segments)
        Supports simple glob matching: "Vehicle.*.Speed", "Vehicle.**"

        @return list of matching paths
    */
    list<string> findPaths(string glob_pattern) {
        # convert glob to regex
        string regex_str = "^";
        list<string> parts = glob_pattern.split(".");
        for (int i = 0; i < parts.size(); i++) {
            if (i > 0) {
                regex_str += "\\.";
            }
            if (parts[i] == "**") {
                regex_str += ".*";
            } else if (parts[i] == "*") {
                regex_str += "[^.]+";
            } else {
                regex_str += regex_escape(parts[i]);
            }
        }
        regex_str += "$";

        list<string> result = ();
        HashIterator it(nodes);
        while (it.next()) {
            if (regex(it.getKey(), regex_str)) {
                push result, it.getKey();
            }
        }

        return result;
    }

    #! Returns the complete flat node map (path to VssNode)
    /** @return a hash mapping every VSS path to its @ref VssNode definition
    */
    hash<string, hash<VssNode>> getAllNodes() {
        return nodes;
    }

    #! Returns the VSS specification version
    /** @return the version string (e.g. \c "4.0"), or \c "unknown" if not specified
    */
    string getVersion() {
        return vss_version;
    }

    #! Returns the total number of nodes in the tree (branches + leaves)
    /** @return the node count
    */
    int size() {
        return nodes.size();
    }

    #! Builds the children index for O(1) child lookups
    private buildChildrenIndex() {
        children_index = {};
        HashIterator it(nodes);
        while (it.next()) {
            string path = it.getKey();
            int last_dot = path.rfind(".");
            string parent;
            string name;
            if (last_dot >= 0) {
                parent = path.substr(0, last_dot);
                name = path.substr(last_dot + 1);
            } else {
                parent = "";
                name = path;
            }
            if (!exists children_index{parent}) {
                children_index{parent} = ();
            }
            push children_index{parent}, name;
        }
    }

    #! Loads nodes from a raw hash (from JSON/YAML parsing)
    /** Handles the nested VSS format where each key is a path and the value
        contains type, datatype, description, children, etc.
    */
    private loadFromHash(hash<auto> data, *string parent_path) {
        HashIterator it(data);
        while (it.next()) {
            string key = it.getKey();
            auto val = it.getValue();

            if (val.typeCode() != NT_HASH) {
                continue;
            }

            string path = exists parent_path ? parent_path + "." + key : key;

            # if this hash has a "type" key, it's a VSS node definition
            if (exists val.type) {
                string name;
                int dot_pos = path.rfind(".");
                if (dot_pos >= 0) {
                    name = path.substr(dot_pos + 1);
                } else {
                    name = path;
                }

                # separate children from node properties
                *hash<string, auto> custom;
                HashIterator vit(val);
                while (vit.next()) {
                    if (!VssStandardNodeKeys{vit.getKey()}) {
                        # include non-hash values and hash values that aren't child VSS nodes
                        if (vit.getValue().typeCode() != NT_HASH || !exists vit.getValue().type) {
                            if (!exists custom) {
                                custom = {};
                            }
                            custom{vit.getKey()} = vit.getValue();
                        }
                    }
                }

                nodes{path} = <VssNode>{
                    "name": name,
                    "path": path,
                    "type": string(val.type).lwr(),
                    "datatype": val.datatype,
                    "description": val.description ?? "",
                    "unit": val.unit,
                    "min": exists val.min ? number(val.min) : NOTHING,
                    "max": exists val.max ? number(val.max) : NOTHING,
                    "allowed": val.allowed,
                    "default_value": val."default",
                    "comment": val.comment,
                    "deprecation": val.deprecation,
                    "instances": val.instances,
                    "is_delete": val."delete",
                    "custom": custom,
                };

                # recurse into children if present
                if (exists val.children && val.children.typeCode() == NT_HASH) {
                    loadFromHash(val.children, path);
                }

                # also recurse into any sub-hashes that look like child VSS nodes
                HashIterator cit(val);
                while (cit.next()) {
                    if (cit.getValue().typeCode() == NT_HASH
                        && !VssStandardNodeKeys{cit.getKey()}
                        && exists cit.getValue().type
                        && VssValidNodeTypes{string(cit.getValue().type).lwr()}) {
                        loadFromHash({cit.getKey(): cit.getValue()}, path);
                    }
                }
            }
        }
    }

    #! Escapes special regex characters in a string
    private static string regex_escape(string str) {
        return regex_subst(str, "([\\[\\]{}()*+?.\\\\^$|])", "\\\\$1", RE_Global);
    }
}

} # namespace VssLoader
