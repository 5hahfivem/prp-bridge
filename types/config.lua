---@meta

---@alias AvailableFrameworks 'qbx_core' | 'qb-core' | 'es_extended' | 'nd_core' | 'mythic-base'

---@alias AvailableInventories 'ox_inventory' | 'origen_inventory' | 'tgiann-inventory' | 'mythic-inventory'

---@alias AvailablePhones 'lb-phone' | 'yseries' | 'yphone' | 'yflip' | 'npwd' | 'roadphone' | '17mov_phone' | 'gksphone' | 'mythic-phone'

---@alias AvailableTargets 'ox_target' | 'qb-target' | 'sleepless_interact' | 'mythic-targeting'

---@alias AvailableMedicals 'qbx_medical' | 'esx_ambulancejob' | 'wasabi_ambulance' | 'ars_ambulancejob' | 'osp_ambulance' | 'p-ambulancejob' | 'nd_ambulance' | 'qb-ambulancejob' | 'randol_medical' | 'tk_ambulancejob' | 'mythic-damage'

---@alias AvailableDispatches 'ps-dispatch' | 'origen_police' | 'cd_dispatch' | 'rcore_dispatch' | 'tk_dispatch' | 'lb-tablet' | 'aty_dispatch' | 'codem-dispatch' | 'core_dispatch' | 'mythic-mdt'

---@alias AvailableMinigames 'prp-minigames'

---@alias AvailableVehicleKeys 'cd_garage' | 'mVehicle' | 'okokGarage' | 'qb-vehiclekeys' | 'qbx_vehiclekeys' | 'vehicles_keys' | 'wasabi_carlock' | 'nd_core' | 'mrnewbvehiclekeys' | 'Renewed-Vehiclekeys' | 'mythic-vehicles'

---@alias VehicleClasses 'X' | 'S' | 'A' | 'B' | 'C' | 'D' | 'E' | 'EV1' | 'EV2'
---@alias VehicleTypes 'car' | 'bike' | 'quadbike' | 'bicycle' | 'heli' | 'plane' | 'boat' | 'trailer' | 'train' | 'blimp' | 'submarine' | 'submarinecar' | 'amphibious_quadbike' | 'amphibious_automobile'

---@class VehicleData
---@field manufacturer string
---@field label string
---@field name string
---@field class VehicleClasses
---@field type VehicleTypes
---@field inBoosting boolean

---@alias AvailableVehicleFuel 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel' | 'lc_fuel' | 'qb-fuel' | 'Renewed-Fuel' | 'mythic-fuel'