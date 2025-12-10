//!
//! Generic driver for the ASAIR AHT30 Temperature and Humidity Sensor.
//!
//! Datasheet:
//! * AHT30: https://eleparts.co.kr/data/goods_attach/202306/good-pdf-12751003-1.pdf
//!
const std = @import("std");
const mdf = @import("../framework.zig");

pub const AHT30 = struct {
    dev: mdf.base.I2C_Device,
    address: mdf.base.I2C_Device.Address,
    reading: packed struct {
        status: packed struct {
            reserved: u2,

            /// 0 -- The calibrated capacitance data is within the CMP interrupt threshold range
            /// 1 -- The calibrated capacitance data is outside the CMP interrupt threshold range
            cmp_interrupt: u1,

            /// 0 -- The calibration calculation function is disabled, and the output data is the raw data output by the ADC
            /// 1 -- The calibration calculation function is enabled, and the output data is the calibrated data
            calibration_enabled: bool,

            /// 0 -- Indicates that the integrity test failed, indicating that there is an error in the OTP data
            /// 1 -- Indicates that the OTP memory data integrity test (CRC) passed,
            crc_flag: u1,
            mode_status: enum(u2) { nor, cyc, cmd, _ },

            /// 0 -- Sensor idle, in sleep state
            /// 1 -- Sensor is busy, measuring in progress
            busy: bool,
        },
        relative_humidity_data: u20,
        temperature_data: u20,
        crc: u8,
    },

    const write_measurement_command = [_]u8{ 0xAC, 0x33, 0x00 };

    pub fn init(dev: mdf.base.I2C_Device, address: mdf.base.I2C_Device.Address) !AHT30 {
        return AHT30{
            .dev = dev,
            .address = address,
            .reading = undefined,
        };
    }

    /// For greater precision the data collection cycle should be greater than 1 second
    pub fn read_temperature(self: *const AHT30) !f32 {
        var response: [7]u8 = undefined;
        const read = try self.dev.read(self.address, &response);
        if (read != response.len) {
            return error.InvalidResponseLength;
        }

        const temp_data: u32 = (@as(u32, response[3]) & 0xF) << 16 | @as(u32, response[4]) << 8 | response[5];
        return to_temp(temp_data);
    }

    pub fn read_relative_humidity(self: *const AHT30) !f32 {
        var buffer: [7]u8 = undefined;
        const read = try self.dev.read(self.address, &buffer);
        if (read != buffer.len) {
            return error.InvalidResponseLength;
        }

        self.reading = @bitCast(buffer);
        const temp_data: u32 = @as(u32, self.reading.temperature_data);

        return to_temp(temp_data);
    }

    /// update_readings should be followed by a delay of at least 80ms
    pub fn update_readings(self: *const AHT30) !void {
        try self.dev.write(
            self.address,
            &write_measurement_command,
        );
    }

    pub fn read_temperature_f(self: *const AHT30) !f32 {
        return self.c_to_f(try self.read_temperature());
    }

    fn to_temp(temp_data: u32) !f32 {
        return (@as(f32, @floatFromInt(temp_data)) / 1048576) * 200 - 50;
    }

    pub fn c_to_f(temp_c: f32) f32 {
        return (temp_c * 9 / 5) + 32;
    }
};

test "temp conversions C to F" {
    try std.testing.expectEqual(-40, AHT30.c_to_f(-40));
    try std.testing.expectEqual(32, AHT30.c_to_f(0));
    try std.testing.expectEqual(86, AHT30.c_to_f(30));
}

test "unit conversions to temp" {
    try std.testing.expectEqual(0, AHT30.to_temp(0));
    try std.testing.expectEqual(7.8125E-3, AHT30.to_temp(1));
    try std.testing.expectEqual(-7.8125E-3, AHT30.to_temp(-1));
}

test "temp conversions to units" {
    try std.testing.expectEqual(0, AHT30.to_temp_units(0));
    try std.testing.expectEqual(32640, AHT30.to_temp_units(255));
    try std.testing.expectEqual(-32640, AHT30.to_temp_units(-255));
}
