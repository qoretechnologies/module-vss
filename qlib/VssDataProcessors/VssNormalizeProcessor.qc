# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssNormalizeProcessor.qc Field renaming processor for OEM to VSS mapping

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

#! Renames OEM fields to VSS paths using a field map
/** Transforms records by renaming keys according to a mapping from OEM-specific
    field names to standardized VSS paths.

    Fields not in the mapping are omitted from the output.
*/
public class VssNormalizeProcessor inherits DataProvider::AbstractDataProcessor {
    private {
        #! Mapping from OEM field name to VSS path
        hash<string, string> field_map;
    }

    #! Creates the processor with the given field mapping
    /** @param field_map hash mapping OEM field names to VSS paths
        (e.g. {"veh_spd_kph": "Vehicle.Speed"})
    */
    constructor(hash<string, string> field_map) {
        self.field_map = field_map;
    }

    #! Transforms a record by renaming fields
    private auto submitImpl(code enqueue, auto _data) {
        if (_data.typeCode() != NT_HASH) {
            enqueue(_data);
            return;
        }

        hash<auto> record = _data;
        hash<auto> result = {};

        HashIterator it(record);
        while (it.next()) {
            *string vss_path = field_map{it.getKey()};
            if (exists vss_path) {
                result{vss_path} = it.getValue();
            }
        }

        enqueue(result);
    }

    #! Returns the processor capabilities
    private int getProcessorCapabilitiesImpl() {
        return DataProvider::DPC_TRANSFORM;
    }
}

} # namespace VssDataProcessors
