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
/** Supports request API: returns signal metadata (type, datatype, unit,
    min, max, allowed, description).
*/
public class VssSignalDataProvider inherits DataProvider::AbstractDataProvider {
    private {
        #! The VSS tree
        VssLoader::VssTree tree;

        #! The signal path
        string signal_path;
    }

    #! Creates a signal provider for a specific path
    constructor(VssLoader::VssTree tree, string path) {
        self.tree = tree;
        self.signal_path = path;
    }

    #! Returns the provider name
    string getName() {
        int dot = signal_path.rfind(".");
        if (dot >= 0) {
            return signal_path.substr(dot + 1);
        }
        return signal_path;
    }

    #! Returns provider description
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
