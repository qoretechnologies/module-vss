# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssUnitConvertProcessor.qc Unit conversion processor

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

#! Applies unit conversions to specified fields in a record
/** Converts numeric signal values between measurement units using a
    @ref VssUnitConverter instance. Non-numeric values are silently skipped.

    Common fleet use cases include converting between metric and imperial units
    for multi-region fleet dashboards, or normalizing OBD-II readings to VSS
    standard units.

    @par Multi-Region Fleet Dashboard Example
    @code{.py}
    VssUnitConverter converter();
    # Convert European km/h and Celsius to US mph and Fahrenheit
    VssUnitConvertProcessor unit_proc(converter, {
        "Vehicle.Speed": {"from_unit": "km/h", "to_unit": "mph"},
        "Vehicle.Powertrain.CombustionEngine.ECT": {"from_unit": "celsius", "to_unit": "fahrenheit"},
        "Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Pressure": {"from_unit": "kPa", "to_unit": "psi"},
    });
    # Input:  {"Vehicle.Speed": 100}
    # Output: {"Vehicle.Speed": 62.1371}
    @endcode
*/
public class VssUnitConvertProcessor inherits DataProvider::AbstractDataProcessor {
    private {
        #! Unit converter
        VssLoader::VssUnitConverter converter;

        #! Conversion map: {vss_path: {"from_unit": string, "to_unit": string}}
        hash<string, hash<string, string>> conversion_map;
    }

    #! Creates the processor
    /** @param converter the unit converter to use
        @param conversion_map hash mapping VSS paths to {from_unit, to_unit} specs
    */
    constructor(VssLoader::VssUnitConverter converter,
            hash<string, hash<string, string>> conversion_map) {
        self.converter = converter;
        self.conversion_map = conversion_map;
    }

    #! Applies unit conversions to matching numeric fields in the record
    /** @param enqueue the callback to enqueue the converted record
        @param _data the input data; non-hash data is passed through unchanged
    */
    private auto submitImpl(code enqueue, auto _data) {
        if (_data.typeCode() != NT_HASH) {
            enqueue(_data);
            return;
        }

        hash<auto> record = _data;

        HashIterator it(conversion_map);
        while (it.next()) {
            string path = it.getKey();
            if (exists record{path}) {
                auto val = record{path};
                # only convert numeric values; skip non-numeric fields silently
                if (val.typeCode() == NT_INT || val.typeCode() == NT_FLOAT
                    || val.typeCode() == NT_NUMBER) {
                    hash<string, string> spec = it.getValue();
                    record{path} = converter.convert(
                        float(val),
                        spec.from_unit,
                        spec.to_unit,
                    );
                }
            }
        }

        enqueue(record);
    }

    #! Returns the processor capabilities (transform only — all records pass through)
    /** @return @ref DataProvider::DPC_TRANSFORM
    */
    private int getProcessorCapabilitiesImpl() {
        return DataProvider::DPC_TRANSFORM;
    }
}

} # namespace VssDataProvider
