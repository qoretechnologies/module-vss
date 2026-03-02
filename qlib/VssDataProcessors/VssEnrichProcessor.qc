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

public namespace VssDataProcessors {

#! Adds metadata to records
/** Enriches records with static metadata and optionally adds a timestamp.
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

    #! Enriches a record with metadata
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

    #! Returns the processor capabilities
    private int getProcessorCapabilitiesImpl() {
        return DataProvider::DPC_TRANSFORM;
    }
}

} # namespace VssDataProcessors
