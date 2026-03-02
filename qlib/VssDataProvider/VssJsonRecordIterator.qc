# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssJsonRecordIterator.qc SAX-based JSON record iterator for VSS data

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

%ifdef NoJson
# JSON module not available; VssReadDataProvider constructor throws a descriptive error
%else

public namespace VssDataProvider {

#! SAX-based JSON record iterator for VSS data
/** Parses a JSON array of objects (or a bare top-level JSON object) from an InputStream
    using @ref Qore::Json::JsonSaxParser "JsonSaxParser". Records are reconstructed via
    a stack-based state machine during SAX parsing, avoiding construction of a full DOM
    tree. All records are collected in memory for random-access iteration.

    Also supports a bare top-level JSON object, which is emitted as a single record.

    @par Fleet JSON Telemetry Parsing Example
    @code{.py}
    # Parse JSON telemetry data from an edge device file upload
    InputStream stream = FileLocationHandler::getBinaryStreamFromLocation(
        "file:///data/fleet/truck-42.json",
    );
    # JSON format: [{"Vehicle.Speed": 85, "Vehicle.Powertrain.CombustionEngine.ECT": 90}, ...]
    VssJsonRecordIterator it(stream);
    while (it.next()) {
        hash<auto> record = it.getValue();
        printf("Speed: %y km/h\n", record."Vehicle.Speed");
    }
    @endcode

    @note Records are collected in memory during construction; the input stream is fully
    consumed in the constructor
*/
public class VssJsonRecordIterator inherits Qore::AbstractIterator {
    private {
        #! Collected records from SAX parsing
        list<auto> records = ();

        #! Current position in the records list (-1 = before first)
        int pos = -1;
    }

    #! Creates the iterator and parses the JSON stream
    /** @param stream the InputStream containing JSON data (array of objects)
    */
    constructor(InputStream stream) {
        JsonSaxParser parser();

        # Stack-based record reconstruction
        list<auto> data_stack = ();
        list<string> type_stack = ();
        list<*string> key_stack = ();
        bool in_top_array = False;

        # Helper closure to add a value to the current top-of-stack container
        code add_to_top = sub (auto value) {
            int idx = data_stack.size() - 1;
            if (type_stack[idx] == "hash") {
                data_stack[idx]{key_stack[idx]} = value;
            } else {
                push data_stack[idx], value;
            }
        };

        parser.parseStream(stream, sub (hash<auto> event) {
            switch (event.type) {
                case JsonSaxArrayStart: {
                    if (!in_top_array && !data_stack) {
                        # Top-level array
                        in_top_array = True;
                    } else {
                        # Nested array inside a record
                        push data_stack, list();
                        push type_stack, "list";
                        push key_stack, NOTHING;
                    }
                    break;
                }

                case JsonSaxObjectStart: {
                    push data_stack, {};
                    push type_stack, "hash";
                    push key_stack, NOTHING;
                    break;
                }

                case JsonSaxKey: {
                    key_stack[key_stack.size() - 1] = event.value;
                    break;
                }

                case JsonSaxString:
                case JsonSaxNumber:
                case JsonSaxBoolean: {
                    if (data_stack) {
                        add_to_top(event.value);
                    }
                    break;
                }

                case JsonSaxNull: {
                    if (data_stack) {
                        add_to_top(NOTHING);
                    }
                    break;
                }

                case JsonSaxObjectEnd:
                case JsonSaxArrayEnd: {
                    if (data_stack) {
                        auto completed = pop data_stack;
                        pop type_stack;
                        pop key_stack;
                        if (!data_stack) {
                            # Top-level record completed
                            push records, completed;
                        } else {
                            add_to_top(completed);
                        }
                    } else {
                        # Top-level array end
                        in_top_array = False;
                    }
                    break;
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
