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

    Can be constructed from:
    - A pre-exported JSON or YAML file
    - A pre-parsed node map (from VssVspecParser)
*/
public class VssTree {
    private {
        #! Flat path-to-node map
        hash<string, hash<VssNode>> nodes;

        #! VSS specification version
        string vss_version;
    }

    #! Creates a VssTree from a pre-exported JSON or YAML file
    /** @param filepath path to the file (.json, .yaml, .yml, or .vspec)

        @throw VSS-LOAD-ERROR thrown when the file format is unsupported or parsing fails
    */
    constructor(string filepath) {
        auto parsed;
        if (filepath =~ /\.json$/i) {
            string content = ReadOnlyFile::readTextFile(filepath);
            try {
                parsed = parse_json(content);
            } catch (hash<ExceptionInfo> ex) {
                throw "VSS-LOAD-ERROR", sprintf("failed to parse JSON file %y: %s", filepath, ex.desc), ex;
            }
        } else if (filepath =~ /\.(yaml|yml)$/i) {
            string content = ReadOnlyFile::readTextFile(filepath);
            try {
                parsed = parse_yaml(content);
            } catch (hash<ExceptionInfo> ex) {
                throw "VSS-LOAD-ERROR", sprintf("failed to parse YAML file %y: %s", filepath, ex.desc), ex;
            }
        } else if (filepath =~ /\.vspec$/i) {
            VssVspecParser parser(dirname(filepath));
            nodes = parser.parseFile(basename(filepath));
            vss_version = "unknown";
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
    }

    #! Creates a VssTree from a pre-parsed node map
    /** @param nodes flat map of VSS path to VssNode
        @param version the VSS specification version (optional)
    */
    constructor(hash<string, hash<VssNode>> nodes, *string version) {
        self.nodes = nodes;
        vss_version = version ?? "unknown";
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
        hash<string, bool> children;
        string prefix = exists parent_path ? parent_path + "." : "";
        int prefix_len = prefix.length();

        HashIterator it(nodes);
        while (it.next()) {
            string path = it.getKey();
            if (prefix_len > 0) {
                if (path.length() <= prefix_len || path.substr(0, prefix_len) != prefix) {
                    continue;
                }
                string remainder = path.substr(prefix_len);
                # only direct children: no dots in remainder
                if (remainder.find(".") < 0) {
                    children{remainder} = True;
                }
            } else {
                # top-level: paths with no dots
                if (path.find(".") < 0) {
                    children{path} = True;
                }
            }
        }

        return keys children;
    }

    #! Returns the child nodes of the given branch
    /** @param branch_path the branch path

        @return list of direct child VssNode hashes
    */
    list<hash<VssNode>> getChildren(string branch_path) {
        list<hash<VssNode>> result = ();
        string prefix = branch_path + ".";
        int prefix_len = prefix.length();

        HashIterator it(nodes);
        while (it.next()) {
            string path = it.getKey();
            if (path.length() > prefix_len
                && path.substr(0, prefix_len) == prefix
                && path.substr(prefix_len).find(".") < 0) {
                push result, it.getValue();
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

    #! Returns the complete flat node map
    hash<string, hash<VssNode>> getAllNodes() {
        return nodes;
    }

    #! Returns the VSS specification version
    string getVersion() {
        return vss_version;
    }

    #! Returns the total number of nodes in the tree
    int size() {
        return nodes.size();
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
                hash<string, bool> node_keys = {
                    "type": True, "datatype": True, "description": True, "unit": True,
                    "min": True, "max": True, "allowed": True, "default": True,
                    "comment": True, "deprecation": True, "instances": True, "delete": True,
                    "children": True,
                };

                *hash<string, auto> custom;
                HashIterator vit(val);
                while (vit.next()) {
                    if (!node_keys{vit.getKey()} && vit.getValue().typeCode() != NT_HASH) {
                        if (!exists custom) {
                            custom = {};
                        }
                        custom{vit.getKey()} = vit.getValue();
                    }
                }

                nodes{path} = <VssNode>{
                    "name": name,
                    "path": path,
                    "type": string(val.type).lwr(),
                    "datatype": val.datatype,
                    "description": val.description ?? "",
                    "unit": val.unit,
                    "min": exists val.min ? float(val.min) : NOTHING,
                    "max": exists val.max ? float(val.max) : NOTHING,
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

                # also recurse into any sub-hashes that look like child nodes
                HashIterator cit(val);
                while (cit.next()) {
                    if (cit.getValue().typeCode() == NT_HASH
                        && !node_keys{cit.getKey()}
                        && exists cit.getValue().type) {
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
