# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssSignalDataProvider.qc VSS signal metadata provider

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

#! Provider for VSS leaf signal metadata
/** Represents a single VSS signal node (sensor, actuator, or attribute). Supports the
    request API to return signal metadata including type, datatype, unit, min/max range,
    allowed values, and description.

    These providers are created automatically when navigating to a leaf node via
    @ref VssCatalogDataProvider.

    @par IoT Telemetry Configuration Example
    @code{.py}
    # Look up tire pressure signal metadata for IoT sensor configuration
    AbstractDataProvider tire = root.getChildProvider("catalog")
        .getChildProvider("Vehicle").getChildProvider("Chassis")
        .getChildProvider("Axle").getChildProvider("Row1")
        .getChildProvider("Wheel").getChildProvider("Left")
        .getChildProvider("Tire").getChildProvider("Pressure");
    hash<auto> meta = tire.doRequest({});
    printf("Signal: %s\n", meta.path);     # Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Pressure
    printf("Type: %s\n", meta.datatype);   # uint16
    printf("Unit: %s\n", meta.unit);       # kPa
    printf("Range: [%y, %y]\n", meta.min, meta.max); # [0, 1000]
    @endcode
*/
public class VssSignalDataProvider inherits DataProvider::AbstractDataProvider {
    public {
        #! Response type
        static VssSignalResponseDataType ResponseType();
    }

    private {
        #! The VSS tree
        VssLoader::VssTree tree;

        #! The signal path
        string signal_path;
    }

    #! Creates a signal provider for a specific VSS leaf path
    /** @param tree the loaded VSS tree
        @param path the full dot-separated VSS path (e.g. \c "Vehicle.Speed")
    */
    constructor(VssLoader::VssTree tree, string path) {
        self.tree = tree;
        self.signal_path = path;
    }

    #! Returns the leaf segment of the signal path as the provider name
    /** @return the leaf name (e.g. \c "Speed" for path \c "Vehicle.Speed")
    */
    string getName() {
        int dot = signal_path.rfind(".");
        if (dot >= 0) {
            return signal_path.substr(dot + 1);
        }
        return signal_path;
    }

    #! Returns the signal's human-readable description from the VSS catalog
    /** @return the signal description, or @ref nothing if the node is not found
    */
    *string getDesc() {
        *hash<VssLoader::VssNode> node = tree.getNode(signal_path);
        if (exists node) {
            return node.description;
        }
        return NOTHING;
    }

    #! Handles request: returns signal metadata
    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        *hash<VssLoader::VssNode> node = tree.getNode(signal_path);
        if (!exists node) {
            throw "VSS-SIGNAL-ERROR", sprintf("signal %y not found", signal_path);
        }

        return {
            "path": node.path,
            "name": node.name,
            "type": node.type,
            "datatype": node.datatype,
            "description": node.description,
            "unit": node.unit,
            "min": node.min,
            "max": node.max,
            "allowed": node.allowed,
            "default_value": node.default_value,
            "deprecation": node.deprecation,
        };
    }

    #! Returns the request type (NOTHING = any request accepted)
    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return NOTHING;
    }

    #! Returns the response type
    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return ResponseType;
    }

    #! Returns provider static info
    private hash<DataProvider::DataProviderInfo> getStaticInfoImpl() {
        return <DataProviderInfo>{
            "name": getName(),
            "desc": getDesc(),
            "type": "VssSignalDataProvider",
            "supports_request": True,
        };
    }
}

} # namespace VssDataProvider
