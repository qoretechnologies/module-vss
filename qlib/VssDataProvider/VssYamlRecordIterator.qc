# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssYamlRecordIterator.qc SAX-based YAML record iterator for VSS data

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

%ifdef NoYaml
# YAML module not available; VssReadDataProvider constructor throws a descriptive error
%else

public namespace VssDataProvider {

#! SAX-based YAML record iterator for VSS data
/** Parses YAML data from an InputStream using
    @ref Qore::Yaml::YamlSaxParser "YamlSaxParser", supporting two formats:
    - **Multi-document**: each YAML document (separated by \c "---") is one record mapping
    - **Sequence of mappings**: a single document with a top-level sequence of mapping records

    Records are reconstructed via a stack-based state machine during SAX parsing,
    avoiding construction of a full DOM tree. All records are collected in memory
    for random-access iteration.

    @par Fleet YAML Telemetry Parsing Example
    @code{.py}
    # Parse multi-document YAML telemetry from a fleet data export
    # YAML format:
    #   ---
    #   Vehicle.Speed: 85
    #   Vehicle.Powertrain.CombustionEngine.ECT: 90
    #   ---
    #   Vehicle.Speed: 92
    #   Vehicle.Powertrain.CombustionEngine.ECT: 91
    InputStream stream = new StringInputStream(yaml_data);
    VssYamlRecordIterator it(stream);
    while (it.next()) {
        hash<auto> record = it.getValue();
        printf("Speed: %y km/h\n", record."Vehicle.Speed");
    }
    @endcode

    @note YAML aliases are not supported; a \c "VSS-YAML-UNSUPPORTED" exception is thrown
    if an alias is encountered. Records are collected in memory during construction; the
    input stream is fully consumed in the constructor.
*/
public class VssYamlRecordIterator inherits Qore::AbstractIterator {
    private {
        #! Collected records from SAX parsing
        list<auto> records = ();

        #! Current position in the records list (-1 = before first)
        int pos = -1;
    }

    #! Creates the iterator and parses the YAML stream
    /** @param stream the InputStream containing YAML data
    */
    constructor(InputStream stream) {
        YamlSaxParser parser();

        # Stack-based record reconstruction
        # Each entry on the stack represents a container being built:
        #   data_stack: the hash {} or list () being constructed
        #   type_stack: "mapping" or "sequence"
        #   expect_key_stack: True if next scalar in a mapping is a key
        #   key_stack: current key name for mappings
        list<auto> data_stack = ();
        list<string> type_stack = ();
        list<bool> expect_key_stack = ();
        list<*string> key_stack = ();

        # Format detection: "unknown", "multi_doc", or "sequence"
        string format = "unknown";

        # Helper closure: add a value to the current top-of-stack container
        code add_to_top = sub (auto value) {
            int idx = data_stack.size() - 1;
            if (type_stack[idx] == "mapping") {
                if (expect_key_stack[idx]) {
                    # This scalar is a mapping key
                    key_stack[idx] = string(value);
                    expect_key_stack[idx] = False;
                } else {
                    # This scalar is a mapping value
                    data_stack[idx]{key_stack[idx]} = value;
                    expect_key_stack[idx] = True;
                }
            } else {
                # Sequence: append value
                push data_stack[idx], value;
            }
        };

        # Helper closure: pop completed container and emit or merge into parent
        code complete_container = sub () {
            auto completed = pop data_stack;
            pop type_stack;
            pop expect_key_stack;
            pop key_stack;
            if (!data_stack) {
                # Top-level container completed — this is a record
                push records, completed;
            } else {
                add_to_top(completed);
            }
        };

        parser.parseStream(stream, sub (hash<YamlSaxEvent> event) {
            switch (event.type) {
                case YAML::YamlSaxEventType::StreamStart:
                case YAML::YamlSaxEventType::StreamEnd:
                case YAML::YamlSaxEventType::DocumentStart:
                case YAML::YamlSaxEventType::DocumentEnd: {
                    # No action needed for stream/document lifecycle events
                    break;
                }

                case YAML::YamlSaxEventType::MappingStart: {
                    if (format == "unknown" && !data_stack) {
                        # First structural event is a mapping → multi-document format
                        format = "multi_doc";
                    }
                    push data_stack, {};
                    push type_stack, "mapping";
                    push expect_key_stack, True;
                    push key_stack, NOTHING;
                    break;
                }

                case YAML::YamlSaxEventType::SequenceStart: {
                    if (format == "unknown" && !data_stack) {
                        # First structural event is a sequence → sequence-of-mappings format
                        # Do not push the top-level sequence to the stack;
                        # records are the mappings inside it
                        format = "sequence";
                    } else {
                        # Nested sequence inside a record
                        push data_stack, list();
                        push type_stack, "sequence";
                        push expect_key_stack, False;
                        push key_stack, NOTHING;
                    }
                    break;
                }

                case YAML::YamlSaxEventType::MappingEnd: {
                    if (data_stack) {
                        complete_container();
                    }
                    break;
                }

                case YAML::YamlSaxEventType::SequenceEnd: {
                    if (data_stack) {
                        complete_container();
                    }
                    # else: top-level sequence end in "sequence" format — no action
                    break;
                }

                case YAML::YamlSaxEventType::Scalar: {
                    if (data_stack) {
                        add_to_top(event.value);
                    }
                    break;
                }

                case YAML::YamlSaxEventType::Alias: {
                    throw "VSS-YAML-UNSUPPORTED",
                        "YAML aliases are not supported; resolve aliases before parsing";
                }
            }
        });
    }

    #! Advances to the next record
    /** @return @ref True if a record is available, @ref False at end of stream
    */
    bool next() {
        if (pos + 1 >= records.size()) {
            pos = records.size();
            return False;
        }
        ++pos;
        return True;
    }

    #! Returns the current record hash
    /** @return the current record as a hash (or auto for bare values)
    */
    auto getValue() {
        return records[pos];
    }

    #! Returns whether the iterator is at a valid position
    /** @return @ref True if the iterator points to a valid record
    */
    bool valid() {
        return pos >= 0 && pos < records.size();
    }
}

} # namespace VssDataProvider

%endif
