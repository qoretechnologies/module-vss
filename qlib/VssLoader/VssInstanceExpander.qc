# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssInstanceExpander.qc VSS instance expansion

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

#! Expands VSS instance specifications into concrete paths
/** VSS branches can have an "instances" attribute that defines how the branch
    should be instantiated (e.g. Row[1,4] creates Row1, Row2, Row3, Row4).

    This class expands all instance specifications in a node map, creating
    concrete paths for each instance.
*/
public class VssInstanceExpander {
    #! Expands all instance specifications in the given node map
    /** @param nodes the input node map (may contain branches with instances)

        @return a new node map with instances expanded to concrete paths
    */
    static hash<string, hash<VssNode>> expandAll(hash<string, hash<VssNode>> nodes) {
        # collect branches that have instances
        list<string> instance_branches = ();
        HashIterator it(nodes);
        while (it.next()) {
            hash<VssNode> node = it.getValue();
            if (node.type == VssNodeType_BRANCH && exists node.instances) {
                push instance_branches, it.getKey();
            }
        }

        if (!instance_branches.size()) {
            return nodes;
        }

        hash<string, hash<VssNode>> result = nodes;

        # process instance branches (process deepest first to handle nested instances)
        # sort by path depth (deepest first)
        instance_branches = sort(instance_branches, int sub (string a, string b) {
            int depth_a = a.split(".").size();
            int depth_b = b.split(".").size();
            return depth_b <=> depth_a;
        });

        foreach string branch_path in (instance_branches) {
            if (!exists result{branch_path}) {
                continue;
            }
            hash<VssNode> branch = result{branch_path};
            list<string> instance_names = VssInstanceExpander::parseInstanceSpec(branch.instances);

            # find all children of this branch
            string prefix = branch_path + ".";
            list<string> child_paths = ();
            HashIterator cit(result);
            while (cit.next()) {
                if (cit.getKey() != branch_path
                    && cit.getKey().length() > prefix.length()
                    && cit.getKey().substr(0, prefix.length()) == prefix) {
                    push child_paths, cit.getKey();
                }
            }

            # create expanded instances
            foreach string inst_name in (instance_names) {
                # create the instance branch node
                string inst_path = branch_path.substr(0, branch_path.length() - branch.name.length())
                    + inst_name;
                if (inst_path =~ /^\./) {
                    inst_path = inst_path.substr(1);
                }

                # determine the correct parent path prefix
                # the instance replaces the branch name segment in the path
                string parent_prefix;
                int last_dot = branch_path.rfind(".");
                if (last_dot >= 0) {
                    parent_prefix = branch_path.substr(0, last_dot) + ".";
                } else {
                    parent_prefix = "";
                }

                string new_branch_path = parent_prefix + inst_name;

                hash<VssNode> inst_branch = branch;
                inst_branch.name = inst_name;
                inst_branch.path = new_branch_path;
                delete inst_branch.instances;
                result{new_branch_path} = inst_branch;

                # duplicate children under the new instance path
                foreach string child_path in (child_paths) {
                    string child_suffix = child_path.substr(prefix.length());
                    string new_child_path = new_branch_path + "." + child_suffix;

                    hash<VssNode> child = result{child_path};
                    child.path = new_child_path;
                    result{new_child_path} = child;
                }
            }

            # remove original template branch and its children
            delete result{branch_path};
            foreach string child_path in (child_paths) {
                delete result{child_path};
            }
        }

        return result;
    }

    #! Parses an instance specification into a list of instance names
    /** Supports:
        - String list: ["Left", "Right"]
        - Numeric range: "Row[1,4]" -> ("Row1", "Row2", "Row3", "Row4")
        - Simple list of strings

        @param spec the instance specification from the VSS node

        @return list of concrete instance names
    */
    static list<string> parseInstanceSpec(auto spec) {
        # list of strings: ["Left", "Right"]
        if (spec.typeCode() == NT_LIST) {
            # check if the list contains sub-lists (multi-dimensional)
            bool has_sublists = False;
            foreach auto item in (spec) {
                if (item.typeCode() == NT_LIST) {
                    has_sublists = True;
                    break;
                }
            }

            if (has_sublists) {
                # multi-dimensional: cartesian product
                list<list<string>> dimensions = ();
                foreach auto dim in (spec) {
                    if (dim.typeCode() == NT_LIST) {
                        list<string> names = ();
                        foreach auto item in (dim) {
                            push names, string(item);
                        }
                        push dimensions, names;
                    } else {
                        push dimensions, (string(dim),);
                    }
                }
                return VssInstanceExpander::cartesianProduct(dimensions);
            }

            # simple list
            list<string> result = ();
            foreach auto item in (spec) {
                push result, string(item);
            }
            return result;
        }

        # string: check for range notation "Name[start,end]"
        if (spec.typeCode() == NT_STRING) {
            *list<string> match = regex_extract(string(spec), "^(\\w+)\\[(\\d+),(\\d+)\\]$");
            if (match) {
                string prefix = match[0];
                int start = int(match[1]);
                int end = int(match[2]);
                list<string> result = ();
                for (int i = start; i <= end; i++) {
                    push result, prefix + string(i);
                }
                return result;
            }

            # plain string - single instance
            return (string(spec),);
        }

        # numeric
        if (spec.typeCode() == NT_INT || spec.typeCode() == NT_FLOAT) {
            return (string(spec),);
        }

        return ();
    }

    #! Computes the cartesian product of multiple dimension lists
    /** @param dimensions list of lists, each containing instance names for one dimension

        @return list of dot-joined path suffixes from the cartesian product
    */
    static list<string> cartesianProduct(list<list<string>> dimensions) {
        if (!dimensions.size()) {
            return ();
        }

        list<string> result = dimensions[0];

        for (int d = 1; d < dimensions.size(); d++) {
            list<string> new_result = ();
            foreach string existing in (result) {
                foreach string dim_val in (dimensions[d]) {
                    push new_result, existing + "." + dim_val;
                }
            }
            result = new_result;
        }

        return result;
    }
}

} # namespace VssLoader
