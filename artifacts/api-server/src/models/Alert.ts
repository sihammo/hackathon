import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IAlert extends Document {
  id: string;
  userId: string;
  userName: string;
  userPhone: string;
  deviceId: string;
  lat: number;
  lng: number;
  wilayaCode: number;
  vehicleType: "car" | "motorcycle" | "truck";
  status: "sent" | "received" | "dispatched" | "arrived" | "resolved" | "cancelled";
  trigger: "impact" | "fall" | "rollover" | "manual";
  peakG: number;
  tilt: number;
  statusTimestamps: Record<string, Date>;
  responses: Record<string, { status: string; timestamps: Record<string, Date> }>;
  notifiedNumbers: string[];
  testMode: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const AlertSchema = new Schema<IAlert>(
  {
    id: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    userName: { type: String, required: true },
    userPhone: { type: String, required: true },
    deviceId: { type: String, required: true, index: true },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    wilayaCode: { type: Number, required: true, index: true },
    vehicleType: {
      type: String,
      enum: ["car", "motorcycle", "truck"],
      default: "car",
    },
    status: {
      type: String,
      enum: ["sent", "received", "dispatched", "arrived", "resolved", "cancelled"],
      default: "sent",
      index: true,
    },
    trigger: {
      type: String,
      enum: ["impact", "fall", "rollover", "manual"],
      default: "impact",
    },
    peakG: { type: Number, default: 0 },
    tilt: { type: Number, default: 0 },
    statusTimestamps: { type: Map, of: Date, default: {} },
    responses: { type: Map, of: Schema.Types.Mixed, default: {} },
    notifiedNumbers: { type: [String], default: [] },
    testMode: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export const AlertModel: Model<IAlert> =
  mongoose.models.Alert || mongoose.model<IAlert>("Alert", AlertSchema);
