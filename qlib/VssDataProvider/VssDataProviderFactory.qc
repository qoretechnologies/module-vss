# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file VssDataProviderFactory.qc VSS data provider factory

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

#! Factory for creating VSS data providers
/** Registered as the \c "vss" factory in the DataProvider framework, enabling VSS catalog
    browsing, signal metadata lookup, and telemetry validation through Qore's data
    provider infrastructure.

    @par Fleet Management Example
    @code{.py}
    # Access the VSS factory for fleet telematics validation
    AbstractDataProviderFactory factory = DataProvider::getFactory("vss");

    # Create a provider backed by the COVESA VSS v4.0 catalog
    AbstractDataProvider provider = factory.create({
        "catalog_path": "/opt/fleet/catalogs/vss_rel_4.0.yaml",
    });

    # Navigate the catalog tree to inspect vehicle speed signal metadata
    AbstractDataProvider speed = provider.getChildProvider("catalog")
        .getChildProvider("Vehicle").getChildProvider("Speed");
    hash<auto> info = speed.doRequest({});
    printf("Unit: %s, Range: [%y, %y]\n", info.unit, info.min, info.max);
    # Unit: km/h, Range: [0, 600]

    # Validate incoming OBD-II telemetry against the VSS catalog
    AbstractDataProvider validator = provider.getChildProvider("validate");
    hash<auto> result = validator.doRequest({
        "path": "Vehicle.Speed",
        "value": 120,
    });
    printf("Valid: %y\n", result.valid); # Valid: True
    @endcode
*/
public class VssDataProviderFactory inherits DataProvider::AbstractDataProviderFactory {
    public {
        #! Factory metadata
        const FactoryInfo = <DataProviderFactoryInfo>{
            "name": "vss",
            "desc": "Data provider factory for COVESA Vehicle Signal Specification (VSS) catalogs",
            "children_can_support_apis": True,
        };
    }

    #! Returns factory metadata describing the provider's name and capabilities
    /** @return a @ref DataProviderFactoryInfo hash with factory name and description
    */
    hash<DataProviderFactoryInfo> getInfoImpl() {
        return FactoryInfo;
    }

    #! Returns the Qore introspection Class object for VssRootDataProvider
    /** @return the @ref Qore::Reflection::Class "Class" object for VssRootDataProvider
    */
    Class getClassImpl() {
        return Class::forName("VssDataProvider::VssRootDataProvider");
    }

    #! Creates a VssRootDataProvider instance from the given options
    /** @param options constructor options; must include \c "catalog_path"
        @param logger optional logger interface

        @return a new VssRootDataProvider instance
    */
    private DataProvider::AbstractDataProvider createImpl(hash<auto> options,
            *LoggerInterface logger) {
        return new VssRootDataProvider(options);
    }

    #! Returns provider info as a data hash for introspection
    /** @param constructor_options the constructor options to use
        @param with_type_info if True, include detailed type information

        @return a hash with provider info
    */
    *hash<auto> getInfoAsDataImpl(hash<auto> constructor_options, *bool with_type_info) {
        return VssRootDataProvider::ProviderInfo;
    }

    #! Returns a human-readable description of the factory
    /** @return the factory description string
    */
    string getDescImpl() {
        return FactoryInfo.desc;
    }

    #! Returns the provider info hash for the root VSS provider
    /** @return a @ref DataProviderInfo hash describing the provider's capabilities
    */
    private hash<DataProvider::DataProviderInfo> getProviderInfoImpl() {
        return VssRootDataProvider::ProviderInfo;
    }
}

} # namespace VssDataProvider
