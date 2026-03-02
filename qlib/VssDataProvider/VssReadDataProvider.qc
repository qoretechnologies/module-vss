# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssReadDataProvider.qc VSS streaming read data provider (DPAT_FIND)

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

#! Provides a data provider for reading VSS telemetry data from JSON or YAML files
/** Supports generic record search operators and options.

    Reads VSS data records using SAX streaming parsers, processing files
    record-by-record without loading the entire file into memory.

    @par Fleet Data Ingestion Example
    @code{.py}
    # Read vehicle telemetry records from a JSON file collected by fleet edge devices
    VssReadDataProvider reader({"path": "file:///data/fleet/truck-42-2026-03-01.json"});

    # Search for all records with speed above 100 km/h
    AbstractDataProviderRecordIterator i = reader.searchRecords(
        {"Vehicle.Speed": {">": 100}},
    );
    while (i.next()) {
        hash<auto> rec = i.getValue();
        printf("Speed: %y km/h at %s\n", rec."Vehicle.Speed",
            rec."Vehicle.CurrentLocation.Timestamp");
    }
    @endcode

    @par Stream Processing Example
    @code{.py}
    # Read from an input stream (e.g., HTTP request body)
    VssReadDataProvider reader({
        "stream": http_request.getInputStream(),
        "format": "json",
    });

    # Process all records
    AbstractDataProviderRecordIterator i = reader.searchRecords();
    while (i.next()) {
        processRecord(i.getValue());
    }
    @endcode

    @par Inline Data Example
    @code{.py}
    # Parse inline YAML telemetry data for testing or small payloads
    VssReadDataProvider reader({
        "data": "- Vehicle.Speed: 85\n  Vehicle.Powertrain.CombustionEngine.ECT: 90\n",
        "format": "yaml",
    });
    @endcode
*/
public class VssReadDataProvider inherits DataProvider::AbstractDataProvider {
    public {
        #! Provider info
        const ProviderInfo = <DataProviderInfo>{
            "type": "VssReadDataProvider",
            "supports_read": True,
            "has_record": True,
            "constructor_options": ConstructorOptions,
            "search_options": GenericRecordSearchOptions,
        };

        #! Constructor options
        const ConstructorOptions = {
            "path": <DataProviderOptionInfo>{
                "display_name": "Input Path",
                "short_desc": "Location of the vehicle telemetry data file",
                "type": AbstractDataProviderTypeMap."string",
                "desc": "Path or URL to the vehicle telemetry data file to read; use instead of "
                    "`stream` or `data`",
                "example_value": "file:///data/telemetry.json",
            },
            "stream": <DataProviderOptionInfo>{
                "display_name": "Input Stream",
                "short_desc": "Stream providing vehicle telemetry data",
                "type": AbstractDataProviderType::get(new Type("InputStream")),
                "desc": "A binary input stream providing vehicle telemetry data; use instead of "
                    "`path` or `data`",
            },
            "data": <DataProviderOptionInfo>{
                "display_name": "Inline Data",
                "short_desc": "Vehicle telemetry data provided inline",
                "type": AbstractDataProviderTypeMap."string",
                "desc": "Vehicle telemetry data provided directly as a JSON or YAML string; use "
                    "instead of `path` or `stream`",
            },
            "format": <DataProviderOptionInfo>{
                "display_name": "Data Format",
                "short_desc": "Format of the telemetry data file",
                "type": AbstractDataProviderTypeMap."*string",
                "desc": "Format of the telemetry data: `json` or `yaml`; auto-detected from the "
                    "file extension if not provided",
                "default_value": NOTHING,
                "allowed_values": (
                    <AllowedValueInfo>{
                        "display_name": "JSON",
                        "short_desc": "JSON format",
                        "desc": "Telemetry data as a JSON array of record objects or a single object",
                        "value": "json",
                    },
                    <AllowedValueInfo>{
                        "display_name": "YAML",
                        "short_desc": "YAML format",
                        "desc": "Telemetry data as a YAML multi-document stream or sequence of mappings",
                        "value": "yaml",
                    },
                ),
            },
        };
    }

    private {
        #! The input source name for display
        string input_name;

        #! Detected or specified data format
        string fmt;

        #! Stored file path for re-reading (mutually exclusive with stored_data)
        *string stored_path;

        #! Stored data content for re-reading (used for inline data and stream inputs)
        *string stored_data;
    }

    #! Creates the data provider from a hash of options
    /** @param options option hash with `path`, `stream`, or `data` and optional `format`

        @throw VSS-READ-ERROR missing or conflicting input options
        @throw VSS-FORMAT-ERROR unknown or missing format
        @throw JSON-MODULE-MISSING json module not available
        @throw YAML-MODULE-MISSING yaml module not available
    */
    constructor(*hash<auto> options) {
        # Validate mutually exclusive input options
        int source_count = (exists options.path ? 1 : 0)
            + (exists options.stream ? 1 : 0)
            + (exists options.data ? 1 : 0);
        if (source_count == 0) {
            throw "VSS-READ-ERROR", "one of 'path', 'stream', or 'data' options is required";
        }
        if (source_count > 1) {
            throw "VSS-READ-ERROR", "options 'path', 'stream', and 'data' are mutually exclusive";
        }

        # Determine format
        *string format = options.format;

        if (exists options.path) {
            string path = options.path;
            input_name = path;
            stored_path = path;
            if (!exists format) {
                format = detectFormat(path);
            }
        } else if (exists options.stream) {
            input_name = sprintf("stream %s", self.uniqueHash());
            # read stream content so the data can be re-parsed on subsequent searches
            StreamReader reader(options.stream);
            stored_data = reader.readString(-1);
        } else {
            input_name = sprintf("inline data %s", self.uniqueHash());
            stored_data = options.data;
        }

        if (!exists format) {
            throw "VSS-FORMAT-ERROR", "cannot determine data format; specify the 'format' option "
                "('json' or 'yaml')";
        }

        # validate format early
        if (format != "json" && format != "yaml") {
            throw "VSS-FORMAT-ERROR", sprintf("unknown data format %y; supported formats: 'json', 'yaml'",
                format);
        }

        fmt = format;
    }

    #! Returns the data provider name (the input source identifier)
    /** @return the input name (file path, stream ID, or inline data ID)
    */
    string getName() {
        return input_name;
    }

    #! Returns a human-readable description of this read provider
    /** @return the provider description string
    */
    *string getDesc() {
        return "VSS streaming read data provider for " + input_name;
    }

    #! Returns an iterator for zero or more records matching the search options
    /** @param where_cond the search criteria
        @param search_options the search options after processing by validateSearchOptions()
    */
    private AbstractDataProviderRecordIterator searchRecordsImpl(*hash<auto> where_cond,
            *hash<auto> search_options) {
        return new DefaultRecordIterator(createFreshIterator(), where_cond, search_options);
    }

    #! Returns an iterator for zero or more records matching the search options
    /** @param where_cond the search criteria; supports DataProviderExpression search
        @param search_options the search options after processing by validateSearchOptions()
    */
    private AbstractDataProviderRecordIterator searchRecordsImpl(*hash<DataProviderExpression> where_cond,
            *hash<auto> search_options) {
        return new DefaultRecordIterator(createFreshIterator(), where_cond, search_options);
    }

    #! Creates a fresh iterator for reading data from the stored source
    private AbstractIterator createFreshIterator() {
        InputStream stream;
        if (exists stored_path) {
            stream = FileLocationHandler::getBinaryStreamFromLocation(stored_path);
        } else {
            stream = new StringInputStream(stored_data);
        }
        return createIterator(fmt, stream);
    }

    #! Returns the record type description
    /** VSS telemetry data has a dynamic schema; returns NOTHING to indicate no fixed record type
    */
    private *hash<string, AbstractDataField> getRecordTypeImpl(*hash<auto> search_options) {
        return NOTHING;
    }

    #! Returns data provider static info
    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }

    #! Auto-detects the data format from a file path extension
    /** @param path the file path
        @return "json" or "yaml"
        @throw VSS-FORMAT-ERROR unrecognized file extension
    */
    private static *string detectFormat(string path) {
        if (path =~ /\.json$/i) {
            return "json";
        }
        if (path =~ /\.(yaml|yml)$/i) {
            return "yaml";
        }
        return NOTHING;
    }

    #! Creates the appropriate SAX record iterator for the given format
    /** @param format "json" or "yaml"
        @param stream the input stream
        @return the record iterator
    */
    private static AbstractIterator createIterator(string format, InputStream stream) {
        switch (format) {
            case "json": {
%ifdef NoJson
                throw "JSON-MODULE-MISSING", "cannot read JSON VSS data; the json module is not available";
%else
                return new VssJsonRecordIterator(stream);
%endif
            }
            case "yaml": {
%ifdef NoYaml
                throw "YAML-MODULE-MISSING", "cannot read YAML VSS data; the yaml module is not available";
%else
                return new VssYamlRecordIterator(stream);
%endif
            }
            default: {
                throw "VSS-FORMAT-ERROR", sprintf("unknown data format %y; supported formats: 'json', 'yaml'",
                    format);
            }
        }
    }
}

} # namespace VssDataProvider
