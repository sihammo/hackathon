import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IHotspot extends Document {
  id: string;
  title: string;
  description: string;
  lat: number;
  lng: number;
  wilayaCode: number;
  radius: number;
  severity: "high" | "medium" | "low";
  accidentsCount: number;
}

const HotspotSchema = new Schema<IHotspot>(
  {
    id: { type: String, required: true, unique: true, index: true },
    title: { type: String, required: true },
    description: { type: String, default: "" },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    wilayaCode: { type: Number, required: true, index: true },
    radius: { type: Number, default: 250 },
    severity: {
      type: String,
      enum: ["high", "medium", "low"],
      default: "high",
    },
    accidentsCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

export const HotspotModel: Model<IHotspot> =
  mongoose.models.Hotspot || mongoose.model<IHotspot>("Hotspot", HotspotSchema);
