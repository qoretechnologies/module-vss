# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssOverlayMerger.qc VSS overlay merge operations

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

#! Merges VSS overlays into a base node map
/** VSS overlays allow:
    - Adding new nodes
    - Modifying attributes of existing nodes (overlay wins on conflict)
    - Deleting nodes (and their children) via the "delete" marker
*/
public class VssOverlayMerger {
    #! Applies a single overlay to a base node map
    /** @param base the base node map
        @param overlay the overlay node map to apply

        @return the merged node map
    */
    static hash<string, hash<VssNode>> applyOverlay(
            hash<string, hash<VssNode>> base,
            hash<string, hash<VssNode>> overlay) {
        hash<string, hash<VssNode>> result = base;

        HashIterator it(overlay);
        while (it.next()) {
            string path = it.getKey();
            hash<VssNode> overlay_node = it.getValue();

            # delete operation: remove path and all children
            if (overlay_node.is_delete) {
                # remove this path
                delete result{path};

                # remove all children
                string prefix = path + ".";
                list<string> to_remove = ();
                HashIterator rit(result);
                while (rit.next()) {
                    if (rit.getKey().length() > prefix.length()
                        && rit.getKey().substr(0, prefix.length()) == prefix) {
                        push to_remove, rit.getKey();
                    }
                }
                foreach string remove_path in (to_remove) {
                    delete result{remove_path};
                }
                continue;
            }

            # existing path: merge attributes (overlay wins)
            if (exists result{path}) {
                hash<VssNode> base_node = result{path};
                # overlay each non-NOTHING field
                if (exists overlay_node.type) {
                    base_node.type = overlay_node.type;
                }
                if (exists overlay_node.datatype) {
                    base_node.datatype = overlay_node.datatype;
                }
                if (overlay_node.description.length()) {
                    base_node.description = overlay_node.description;
                }
                if (exists overlay_node.unit) {
                    base_node.unit = overlay_node.unit;
                }
                if (exists overlay_node.min) {
                    base_node.min = overlay_node.min;
                }
                if (exists overlay_node.max) {
                    base_node.max = overlay_node.max;
                }
                if (exists overlay_node.allowed) {
                    base_node.allowed = overlay_node.allowed;
                }
                if (exists overlay_node.default_value) {
                    base_node.default_value = overlay_node.default_value;
                }
                if (exists overlay_node.comment) {
                    base_node.comment = overlay_node.comment;
                }
                if (exists overlay_node.deprecation) {
                    base_node.deprecation = overlay_node.deprecation;
                }
                if (exists overlay_node.instances) {
                    base_node.instances = overlay_node.instances;
                }
                if (exists overlay_node.custom) {
                    if (exists base_node.custom) {
                        base_node.custom += overlay_node.custom;
                    } else {
                        base_node.custom = overlay_node.custom;
                    }
                }
                result{path} = base_node;
            } else {
                # new path: add to base
                result{path} = overlay_node;
            }
        }

        return result;
    }

    #! Applies multiple overlays in order
    /** @param base the base node map
        @param overlays list of overlay node maps to apply in order

        @return the merged node map
    */
    static hash<string, hash<VssNode>> applyOverlays(
            hash<string, hash<VssNode>> base,
            list<hash<string, hash<VssNode>>> overlays) {
        hash<string, hash<VssNode>> result = base;
        foreach hash<string, hash<VssNode>> overlay in (overlays) {
            result = VssOverlayMerger::applyOverlay(result, overlay);
        }
        return result;
    }
}

} # namespace VssLoader
