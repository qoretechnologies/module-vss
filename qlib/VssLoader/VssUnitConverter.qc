# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssUnitConverter.qc VSS unit conversion with factor/offset model

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

#! Provides extensible unit conversion using a factor/offset model
/** Conversion formula: target = source * factor + offset

    Includes built-in automotive conversions and supports custom conversions
    from YAML config files or programmatic registration.

    Inverse conversions are auto-registered: source = (target - offset) / factor
*/
public class VssUnitConverter {
    private {
        #! Conversion registry: {from_unit: {to_unit: hash<VssUnitConversion>}}
        hash<string, hash<string, hash<VssUnitConversion>>> conversions;
    }

    #! Creates a converter with built-in automotive conversions
    constructor() {
        conversions = {};
        registerBuiltinConversions();
    }

    #! Creates a converter with built-in + custom conversions from a YAML config
    /** @param config_path path to the YAML config file

        @throw VSS-UNIT-CONFIG-ERROR thrown when the config file is invalid
    */
    constructor(string config_path) {
        conversions = {};
        registerBuiltinConversions();
        loadConfig(config_path);
    }

    #! Registers a conversion and its inverse
    /** @param from_unit the source unit
        @param to_unit the target unit
        @param factor multiplication factor
        @param offset additive offset (default: 0.0)
    */
    registerConversion(string from_unit, string to_unit, float factor, float offset = 0.0) {
        # register forward conversion
        if (!exists conversions{from_unit}) {
            conversions{from_unit} = {};
        }
        conversions{from_unit}{to_unit} = <VssUnitConversion>{
            "from_unit": from_unit,
            "to_unit": to_unit,
            "factor": factor,
            "offset": offset,
        };

        # register inverse: source = (target - offset) / factor
        if (factor != 0.0) {
            if (!exists conversions{to_unit}) {
                conversions{to_unit} = {};
            }
            conversions{to_unit}{from_unit} = <VssUnitConversion>{
                "from_unit": to_unit,
                "to_unit": from_unit,
                "factor": 1.0 / factor,
                "offset": -offset / factor,
            };
        }
    }

    #! Converts a value from one unit to another
    /** @param value the value to convert
        @param from_unit the source unit
        @param to_unit the target unit

        @return the converted value

        @throw VSS-UNIT-ERROR thrown when no conversion is registered for the unit pair
    */
    float convert(float value, string from_unit, string to_unit) {
        if (from_unit == to_unit) {
            return value;
        }

        *hash<VssUnitConversion> conv = conversions{from_unit}{to_unit};
        if (!exists conv) {
            throw "VSS-UNIT-ERROR",
                sprintf("no conversion registered from %y to %y", from_unit, to_unit);
        }

        return value * conv.factor + conv.offset;
    }

    #! Returns True if a conversion is available between the two units
    bool canConvert(string from_unit, string to_unit) {
        if (from_unit == to_unit) {
            return True;
        }
        return exists conversions{from_unit}{to_unit};
    }

    #! Returns a list of all registered unit names
    list<string> getUnits() {
        hash<string, bool> units;
        HashIterator it(conversions);
        while (it.next()) {
            units{it.getKey()} = True;
            HashIterator jt(it.getValue());
            while (jt.next()) {
                units{jt.getKey()} = True;
            }
        }
        return keys units;
    }

    #! Registers built-in automotive unit conversions
    private registerBuiltinConversions() {
        # speed
        registerConversion("km/h", "m/s", 1.0 / 3.6, 0.0);
        registerConversion("km/h", "mph", 0.621371, 0.0);

        # temperature
        registerConversion("celsius", "fahrenheit", 1.8, 32.0);
        registerConversion("celsius", "kelvin", 1.0, 273.15);

        # pressure
        registerConversion("kPa", "bar", 0.01, 0.0);
        registerConversion("kPa", "psi", 0.145038, 0.0);

        # ratio
        registerConversion("percent", "ratio", 0.01, 0.0);

        # distance
        registerConversion("km", "miles", 0.621371, 0.0);

        # mass
        registerConversion("kg", "lb", 2.20462, 0.0);

        # length
        registerConversion("mm", "inches", 0.0393701, 0.0);
    }

    #! Loads custom conversions from a YAML config file
    /** @param config_path path to the YAML config file

        @throw VSS-UNIT-CONFIG-ERROR thrown when the config file is invalid
    */
    private loadConfig(string config_path) {
        string content = ReadOnlyFile::readTextFile(config_path);
        auto config;
        try {
            config = parse_yaml(content);
        } catch (hash<ExceptionInfo> ex) {
            throw "VSS-UNIT-CONFIG-ERROR",
                sprintf("failed to parse unit config %y: %s", config_path, ex.desc), ex;
        }

        if (config.typeCode() != NT_HASH) {
            throw "VSS-UNIT-CONFIG-ERROR",
                sprintf("unit config must be a hash, got %y", config.type());
        }

        *list<auto> conv_list = config.conversions;
        if (!exists conv_list) {
            return;
        }

        foreach hash<auto> conv in (conv_list) {
            if (!exists conv."from" || !exists conv."to" || !exists conv.factor) {
                throw "VSS-UNIT-CONFIG-ERROR",
                    sprintf("conversion entry missing required fields (from, to, factor): %y", conv);
            }
            registerConversion(
                string(conv."from"),
                string(conv."to"),
                float(conv.factor),
                exists conv.offset ? float(conv.offset) : 0.0,
            );
        }
    }
}

} # namespace VssLoader
