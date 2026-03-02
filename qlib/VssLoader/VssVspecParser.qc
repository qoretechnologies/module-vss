# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssVspecParser.qc Native .vspec file parser with #include support

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

#! Parses native .vspec files with #include directive support
/** Reads COVESA VSS \c .vspec files (YAML with \c "#include" directives) and produces
    a flat map of VSS paths to @ref VssNode definitions. Supports:
    - Recursive \c "#include" resolution with circular include detection
    - Mount-point prefixing for included files
    - Path traversal protection (included files must stay under the base directory)

    @par Loading a Custom Fleet VSS Extension
    @code{.py}
    # Parse a fleet-specific VSS extension that adds custom signals
    VssVspecParser parser("/opt/fleet/vss-extensions/");
    hash<string, hash<VssNode>> nodes = parser.parseFile("fleet_signals.vspec");

    # fleet_signals.vspec:
    #   #include obd2_extra.vspec Vehicle.OBD
    #   Vehicle.Fleet:
    #     type: branch
    #     description: Fleet-specific signals
    @endcode
*/
public class VssVspecParser {
    private {
        #! Base directory for resolving relative includes
        string base_dir;

        #! Root directory for path traversal protection (set from the initial parser)
        string root_dir;

        #! Set of already loaded files for circular include detection
        hash<string, bool> loaded_files;
    }

    #! Creates a parser with the given base directory
    /** @param base_dir the base directory for resolving relative #include paths
    */
    constructor(string base_dir) {
        self.base_dir = base_dir;
        self.root_dir = normalize_dir(base_dir);
    }

    #! Parses a .vspec file, resolving #include directives recursively
    /** @param filepath path to the .vspec file (absolute or relative to base_dir)

        @return a flat map of VSS path to VssNode

        @throw VSS-CIRCULAR-INCLUDE thrown when a circular include is detected
        @throw VSS-PARSE-ERROR thrown when the file cannot be parsed
    */
    hash<string, hash<VssNode>> parseFile(string filepath) {
        # resolve to absolute path
        string abs_path;
        if (filepath =~ /^\//) {
            abs_path = filepath;
        } else {
            abs_path = base_dir + "/" + filepath;
        }
        abs_path = normalize_dir(abs_path);

        # path traversal protection: ensure included file stays under the root directory
        if (abs_path.length() < root_dir.length()
            || abs_path.substr(0, root_dir.length()) != root_dir) {
            throw "VSS-PATH-TRAVERSAL",
                sprintf("include path %y resolves to %y which is outside the base directory %y",
                    filepath, abs_path, root_dir);
        }

        # check for circular includes
        if (loaded_files{abs_path}) {
            throw "VSS-CIRCULAR-INCLUDE", sprintf("circular include detected: %y", abs_path);
        }
        loaded_files{abs_path} = True;

        # read and parse
        string content = ReadOnlyFile::readTextFile(abs_path);
        string context_dir = dirname(abs_path);
        return parseContent(content, context_dir);
    }

    #! Parses already-loaded vspec content
    /** @param yaml_content the raw vspec file content (YAML with optional #include lines)
        @param context_dir the directory context for resolving relative #include paths

        @return a flat map of VSS path to VssNode

        @throw VSS-PARSE-ERROR thrown when the content cannot be parsed
    */
    hash<string, hash<VssNode>> parseContent(string yaml_content, string context_dir) {
        # preprocess: separate #include directives from YAML content
        hash<auto> pp = preprocessIncludes(yaml_content);

        hash<string, hash<VssNode>> result = {};

        # parse the YAML portion
        if (pp.yaml_content.length()) {
%ifdef NoYaml
            throw "YAML-MODULE-MISSING", "cannot parse .vspec file; the yaml module is not available";
%else
            auto parsed;
            try {
                parsed = parse_yaml(pp.yaml_content);
            } catch (hash<ExceptionInfo> ex) {
                throw "VSS-PARSE-ERROR", sprintf("failed to parse YAML content: %s", ex.desc), ex;
            }

            if (exists parsed) {
                if (parsed.typeCode() != NT_HASH) {
                    throw "VSS-PARSE-ERROR", sprintf("expected YAML hash, got type %y", parsed.type());
                }
                HashIterator it(parsed);
                while (it.next()) {
                    if (it.getValue().typeCode() != NT_HASH) {
                        throw "VSS-PARSE-ERROR",
                            sprintf("expected hash for node %y, got type %y", it.getKey(),
                                it.getValue().type());
                    }
                    result{it.getKey()} = rawToNode(it.getKey(), it.getValue());
                }
            }
%endif
        }

        # process includes
        foreach hash<auto> inc in (pp.includes) {
            string inc_path;
            if (inc.path =~ /^\//) {
                inc_path = inc.path;
            } else {
                inc_path = context_dir + "/" + inc.path;
            }

            # save and restore loaded_files state for the sub-parser
            VssVspecParser sub_parser(dirname(inc_path));
            sub_parser.root_dir = self.root_dir;
            sub_parser.loaded_files = self.loaded_files;

            hash<string, hash<VssNode>> inc_nodes = sub_parser.parseFile(basename(inc_path));

            # merge loaded_files back
            self.loaded_files += sub_parser.loaded_files;

            # apply mount point prefix if specified
            if (exists inc.mount_point && inc.mount_point.length()) {
                HashIterator it(inc_nodes);
                while (it.next()) {
                    string new_path = inc.mount_point + "." + it.getKey();
                    hash<VssNode> node = it.getValue();
                    node.path = new_path;
                    result{new_path} = node;
                }
            } else {
                result += inc_nodes;
            }
        }

        return result;
    }

    #! Preprocesses content to extract #include directives
    /** @param content the raw file content

        @return a hash with "yaml_content" (string) and "includes" (list of {path, mount_point})
    */
    private hash<auto> preprocessIncludes(string content) {
        list<hash<auto>> includes = ();
        list<string> yaml_lines = ();

        list<string> lines = content.split("\n");
        foreach string line in (lines) {
            if (line =~ /^#include\s/) {
                *list<string> match = regex_extract(line, VSS_INCLUDE_REGEX);
                if (match) {
                    push includes, {
                        "path": match[0],
                        "mount_point": match[1],
                    };
                }
            } else {
                push yaml_lines, line;
            }
        }

        return {
            "yaml_content": yaml_lines.join("\n"),
            "includes": includes,
        };
    }

    #! Converts a raw YAML hash entry to a typed VssNode
    /** @param path the VSS dot-notated path
        @param raw the raw hash from YAML parsing

        @return a typed VssNode hash

        @throw VSS-PARSE-ERROR thrown when required fields are missing or type is invalid
    */
    private hash<VssNode> rawToNode(string path, hash<auto> raw) {
        if (!exists raw.type) {
            throw "VSS-PARSE-ERROR", sprintf("missing required 'type' field for node %y", path);
        }

        string type_str = string(raw.type).lwr();
        if (!VssValidNodeTypes{type_str}) {
            throw "VSS-PARSE-ERROR", sprintf("unknown node type %y for node %y; expected one of: %y",
                raw.type, path, keys VssValidNodeTypes);
        }

        # extract the leaf segment name
        string name;
        int dot_pos = path.rfind(".");
        if (dot_pos >= 0) {
            name = path.substr(dot_pos + 1);
        } else {
            name = path;
        }

        # build custom metadata: any keys not in the standard set
        *hash<string, auto> custom;
        HashIterator it(raw);
        while (it.next()) {
            if (!VssStandardNodeKeys{it.getKey()}) {
                if (!exists custom) {
                    custom = {};
                }
                custom{it.getKey()} = it.getValue();
            }
        }

        return <VssNode>{
            "name": name,
            "path": path,
            "type": type_str,
            "datatype": raw.datatype,
            "description": raw.description ?? "",
            "unit": raw.unit,
            "min": exists raw.min ? number(raw.min) : NOTHING,
            "max": exists raw.max ? number(raw.max) : NOTHING,
            "allowed": raw.allowed,
            "default_value": raw."default",
            "comment": raw.comment,
            "deprecation": raw.deprecation,
            "instances": raw.instances,
            "is_delete": raw."delete",
            "custom": custom,
        };
    }
}

} # namespace VssLoader
