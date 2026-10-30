import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IDevice extends Document {
  id: string;
  userId: string;
  name: string;
  vehicleType: "car" | "motorcycle" | "truck";
  connected: boolean;
  batteryLevel: number;
  signalStrength: number;
  firmwareVersion: string;
  lastSeen: Date;
  registeredAt: Date;
}

const DeviceSchema = new Schema<IDevice>(
  {
    id: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    vehicleType: {
      type: String,
      enum: ["car", "motorcycle", "truck"],
      default: "car",
    },
    connected: { type: Boolean, default: false },
    batteryLevel: { type: Number, default: 100, min: 0, max: 100 },
    signalStrength: { type: Number, default: -75 },
    firmwareVersion: { type: String, default: "v2.1.0-esp32" },
    lastSeen: { type: Date, default: Date.now },
    registeredAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

export const DeviceModel: Model<IDevice> =
  mongoose.models.Device || mongoose.model<IDevice>("Device", DeviceSchema);
