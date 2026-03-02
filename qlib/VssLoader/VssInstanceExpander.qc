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
/** VSS branches can have an \c "instances" attribute that defines how the branch
    should be instantiated. This class expands all instance specifications in a node
    map, creating concrete paths for each instance.

    Supported instance specification formats:
    - String list: \c ["Left", "Right"] → \c Left, \c Right
    - Numeric range: \c "Row[1,4]" → \c Row1, \c Row2, \c Row3, \c Row4
    - Multi-dimensional: \c [["Row1", "Row2"], ["Left", "Right"]] →
      \c Row1.Left, \c Row1.Right, \c Row2.Left, \c Row2.Right

    @par Vehicle Door Instance Expansion Example
    @code{.py}
    # A VSS catalog with Door instances: Door[Row1,Row2] x [Left,Right]
    # Before expansion:
    #   Vehicle.Cabin.Door (branch, instances: [["Row1", "Row2"], ["Left", "Right"]])
    #     Vehicle.Cabin.Door.IsOpen (sensor, boolean)

    hash<string, hash<VssNode>> expanded = VssInstanceExpander::expandAll(nodes);

    # After expansion, concrete paths are created:
    #   Vehicle.Cabin.Door                         (branch, instances removed)
    #   Vehicle.Cabin.Door.Row1                    (intermediate branch)
    #   Vehicle.Cabin.Door.Row1.Left               (branch, copy of Door template)
    #   Vehicle.Cabin.Door.Row1.Left.IsOpen        (sensor, copy of Door.IsOpen)
    #   Vehicle.Cabin.Door.Row1.Right              (branch)
    #   Vehicle.Cabin.Door.Row1.Right.IsOpen       (sensor)
    #   Vehicle.Cabin.Door.Row2.Left               (branch)
    #   Vehicle.Cabin.Door.Row2.Left.IsOpen        (sensor)
    #   Vehicle.Cabin.Door.Row2.Right              (branch)
    #   Vehicle.Cabin.Door.Row2.Right.IsOpen       (sensor)
    @endcode
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

            # create expanded instances nested under the branch
            foreach string inst_name in (instance_names) {
                string new_branch_path = branch_path + "." + inst_name;

                # for multi-dimensional instances (e.g. "Row1.DriverSide"), create
                # intermediate branch nodes for each dimension
                list<string> segments = inst_name.split(".");
                string current_path = branch_path;
                for (int s = 0; s < segments.size() - 1; s++) {
                    current_path += "." + segments[s];
                    if (!exists result{current_path}) {
                        result{current_path} = <VssNode>{
                            "name": segments[s],
                            "path": current_path,
                            "type": VssNodeType_BRANCH,
                            "description": sprintf("Instance dimension %y", segments[s]),
                        };
                    }
                }

                hash<VssNode> inst_branch = branch;
                inst_branch.name = segments[segments.size() - 1];
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

            # keep the original branch but remove its instances attribute
            hash<VssNode> cleaned_branch = result{branch_path};
            delete cleaned_branch.instances;
            result{branch_path} = cleaned_branch;

            # remove template children (they've been duplicated under each instance)
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
