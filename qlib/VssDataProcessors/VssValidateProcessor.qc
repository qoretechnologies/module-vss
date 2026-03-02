# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssValidateProcessor.qc Validation processor against VSS catalog

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

#! Validates records against a VSS catalog
/** Two modes:
    - reject_invalid=True: invalid records are dropped (DPC_FILTER)
    - reject_invalid=False: invalid records are annotated with _vss_validation_errors (DPC_TRANSFORM)
*/
public class VssValidateProcessor inherits DataProvider::AbstractDataProcessor {
    private {
        #! The VSS validator
        VssLoader::VssValidator validator;

        #! Whether to reject (filter out) invalid records
        bool reject_invalid;
    }

    #! Creates the processor
    /** @param tree the VSS tree to validate against
        @param reject_invalid if True, invalid records are dropped; if False, they are annotated
    */
    constructor(VssLoader::VssTree tree, bool reject_invalid = False) {
        self.validator = new VssLoader::VssValidator(tree);
        self.reject_invalid = reject_invalid;
    }

    #! Validates a record
    private auto submitImpl(code enqueue, auto _data) {
        if (_data.typeCode() != NT_HASH) {
            enqueue(_data);
            return;
        }

        hash<auto> record = _data;
        list<hash<VssLoader::VssValidationError>> errors = validator.validateRecord(record);

        if (errors.size()) {
            if (reject_invalid) {
                # DPC_FILTER: drop the record (don't enqueue)
                return;
            }
            # DPC_TRANSFORM: annotate with errors
            # use cast to prevent type narrowing issues
            hash result = cast<hash>(record);
            result._vss_validation_errors = errors;
            enqueue(result);
            return;
        }

        enqueue(record);
    }

    #! Returns the processor capabilities
    private int getProcessorCapabilitiesImpl() {
        if (reject_invalid) {
            return DataProvider::DPC_FILTER;
        }
        return DataProvider::DPC_TRANSFORM;
    }
}

} # namespace VssDataProcessors
