local EventDispatcher = require 'EventDispatcher';
local UltrasonicSensor = require 'UltrasonicSensor';
local Stats = require 'Stats';

local Measurement = {}

Measurement.create = function ()
    local export = {};

    local SPLIT_DISTANCE = 150;
    local MEASUREMENT_INTERVAL = 100;

    local lastIsOccupied;
    local distances = {};

    local measurementFinishedListeners = EventDispatcher.create();

    local timer = tmr.create();

    function export.start()
        rtctime.set(0, 0);

        timer:register(MEASUREMENT_INTERVAL, tmr.ALARM_SEMI, function ()
            UltrasonicSensor.getDistance(function (distance)
                table.insert(distances, 1, distance);

                local size = table.getn(distances);
                if (size > 10) then
                    table.remove(distances);
                end

                local currentDistance = Stats.median(distances);

                if (currentDistance == nil) then
                    timer:start();
                    return;
                end

                print(string.format('Calculated distance: %d, from: %s', currentDistance, sjson.encode(distances)));

                local isOccupied = currentDistance < SPLIT_DISTANCE;
                if (isOccupied ~= lastIsOccupied) then
                    lastIsOccupied = isOccupied;

                    local measurementData = {
                        currentDistance = currentDistance,
                        isOccupied = isOccupied
                    };

                    measurementFinishedListeners.dispatch(measurementData, function ()
                        timer:start();
                    end);
                else
                    timer:start();
                end
            end, function ()
                print('No response from ultrasonic sensor');

                timer:start();
            end);
        end);

        timer:start();
    end

    function export.stop()
        timer:stop();
    end

    function export.addMeasurementFinishedListener(listener)
        measurementFinishedListeners.addListener(listener);
    end

    function export.removeMeasurementFinishedListener(listener)
        measurementFinishedListeners.removeListener(listener);
    end

    return export;
end

Measurement.destroy = function()
    measureTimer.unregister(measureTimer);
end

return Measurement;
