//
//  AsyncMidiConnection.swift
//  
//
//  Created by Dr. Brandon Wiley on 8/1/23.
//

import Foundation
import Logging

import Chord
import MIDIKit
import Socket
import Straw
import TransmissionAsync

public class AsyncMidiConnection: AsyncChannelConnection<MidiChannel>
{
    public init(inputPortName: String, outputPortName: String, _ logger: Logger) throws
    {
        let channel = try MidiChannel(inputPortName, outputPortName)

        super.init(channel, logger)
    }
}

public class MidiChannel: Channel
{
    public typealias R = MidiReadable
    public typealias W = MidiWritable

    public var readable: MidiReadable
    {
        return self.midiReadable
    }

    public var writable: MidiWritable
    {
        return self.midiWritable
    }

    let manager: MIDIManager
    let midiReadable: MidiReadable
    let midiWritable: MidiWritable

    public init(_ inputPortName: String, _ outputPortName: String) throws
    {
        let manager = MIDIManager(clientName: "TransmissionAsyncMidi", model: "TransmissionAsyncMidi", manufacturer: "Operator Foundation")
        self.manager = manager
        self.midiReadable = try MidiReadable(manager, outputPortName)
        self.midiWritable = try MidiWritable(manager, inputPortName)

        try self.manager.start()
    }

    public func close() throws
    {
    }
}

public class MidiReadable: Readable
{
    let manager: MIDIManager
    let straw: Straw = Straw()

    public init(_ manager: MIDIManager, _ outputPortName: String) throws
    {
        self.manager = manager

        let maybeOutput = self.manager.endpoints.outputs.first
        {
            endpoint in

            endpoint.name == outputPortName
        }

        guard let output = maybeOutput else
        {
            throw AsyncMidiConnectionError.unknownOutputPort(outputPortName)
        }

        let tag = "Virtual_MIDI_In"
        try self.manager.addInputConnection(toOutputs: [output], tag: tag, receiver: .events
        {
            [weak self] events in

            DispatchQueue.main.async
            {
                events.forEach
                {
                    self?.received(midiEvent: $0)
                }
            }
        })
    }

    public func read() async throws -> Data
    {
        return try await AsyncAwaitAsynchronizer.async
        {
            return try self.straw.read()
        }
    }

    public func read(_ size: Int) async throws -> Data
    {
        let result = Task
        {
            while self.straw.count < size
            {
                await Task.yield()
            }

            return try self.straw.read(size: size)
        }

        return try await result.value
    }

    func received(midiEvent: MIDIEvent)
    {
        switch midiEvent
        {
            case .cc(let payload):
                let value = payload.value
                let channel = payload.channel

                let value4 = UInt4(truncatingIfNeeded: value.midi1Value)
                let channel4 = channel

                let value8 = UInt8(value4)
                let channel8 = UInt8(channel4)

                let byte = (value8 << 4) | channel8
                let data = Data([byte])

                self.straw.write(data)

            default:
                print("unsuppported midi event: \(midiEvent)")
        }
    }
}

public class MidiWritable: Writable
{
    let tag = "Virtual_MIDI_Out"
    let manager: MIDIManager
    let output: MIDIOutput

    public init(_ manager: MIDIManager, _ inputPortName: String) throws
    {
        self.manager = manager

        try self.manager.addOutput(name: "TransmissionAsyncMidi", tag: self.tag, uniqueID: .userDefaultsManaged(key: self.tag))
        guard let output = self.manager.managedOutputs[self.tag] else
        {
            throw AsyncMidiConnectionError.unknownOutputPort(self.tag)
        }
        self.output = output

        let maybeInput = self.manager.endpoints.inputs.first
        {
            endpoint in

            endpoint.name == inputPortName
        }

        guard let input = maybeInput else
        {
            throw AsyncMidiConnectionError.unknownInputPort(inputPortName)
        }

        try self.manager.addOutputConnection(toInputs: [input], tag: self.tag)
    }

    public func write(_ data: Data) async throws
    {
        try await AsyncAwaitAsynchronizer.async
        {
            for byte in data
            {
                let left = byte >> 4
                let right = byte & 0x00FF

                try self.output.send(event: .cc(11, value: .midi1(UInt7(left)), channel: UInt4(right)))
            }
        }
    }
}

public enum AsyncMidiConnectionError: Error
{
    case readFailed
    case unknownInputPort(String)
    case unknownOutputPort(String)
}
