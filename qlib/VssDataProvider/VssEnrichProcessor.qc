# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssEnrichProcessor.qc Metadata enrichment processor

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

#! Adds metadata to records
/** Enriches each record by merging in static metadata fields and optionally adding a
    high-resolution \c "_vss_timestamp" field with the current time. This is typically
    the final stage in a telemetry data pipeline before persistence.

    @par Fleet Record Enrichment Example
    @code{.py}
    # Add fleet context metadata to every telemetry record before storing
    VssEnrichProcessor enricher({
        "fleet_id": "EU-WEST-42",
        "vehicle_vin": "WBA3A5C55CF256789",
        "source": "obd2-adapter-v3",
    }, True);  # True = add _vss_timestamp

    # Input:  {"Vehicle.Speed": 85, "Vehicle.Powertrain.CombustionEngine.ECT": 90}
    # Output: {"Vehicle.Speed": 85, ..., "fleet_id": "EU-WEST-42",
    #          "vehicle_vin": "WBA3A5C55CF256789", "source": "obd2-adapter-v3",
    #          "_vss_timestamp": 2026-03-01T14:30:22.123456Z}
    @endcode

    @par End-to-End Pipeline Example
    @code{.py}
    # Complete fleet telemetry pipeline: normalize → validate → convert → enrich
    VssTree tree("/opt/fleet/vss_rel_4.0.yaml");
    VssUnitConverter converter();

    list<AbstractDataProcessor> pipeline = (
        new VssNormalizeProcessor(oem_field_map),
        new VssValidateProcessor(tree, True),     # drop invalid records
        new VssUnitConvertProcessor(converter, unit_map),
        new VssEnrichProcessor(fleet_metadata),
    );
    @endcode
*/
public class VssEnrichProcessor inherits DataProvider::AbstractDataProcessor {
    private {
        #! Static metadata to add to each record
        hash<auto> metadata;

        #! Whether to add a _vss_timestamp field
        bool add_timestamp;
    }

    #! Creates the processor
    /** @param metadata static metadata hash to merge into each record
        @param add_timestamp if True, adds a _vss_timestamp field with the current time
    */
    constructor(hash<auto> metadata, bool add_timestamp = True) {
        self.metadata = metadata;
        self.add_timestamp = add_timestamp;
    }

    #! Enriches a record by merging metadata and optionally adding a timestamp
    /** @param enqueue the callback to enqueue the enriched record
        @param _data the input data; non-hash data is passed through unchanged
    */
    private auto submitImpl(code enqueue, auto _data) {
        if (_data.typeCode() != NT_HASH) {
            enqueue(_data);
            return;
        }

        # use cast to prevent type narrowing issues when adding mixed-type keys
        hash result = cast<hash>(_data);

        # add static metadata
        result += metadata;

        # add timestamp
        if (add_timestamp) {
            result._vss_timestamp = now_us();
        }

        enqueue(result);
    }

    #! Returns the processor capabilities (transform only — all records pass through)
    /** @return @ref DataProvider::DPC_TRANSFORM
    */
    private int getProcessorCapabilitiesImpl() {
        return DataProvider::DPC_TRANSFORM;
    }
}

} # namespace VssDataProvider
