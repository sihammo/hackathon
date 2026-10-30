import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IEmergencyContact extends Document {
  id: string;
  userId: string;
  name: string;
  phone: string;
  relation: string;
}

const EmergencyContactSchema = new Schema<IEmergencyContact>(
  {
    id: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    phone: { type: String, required: true },
    relation: { type: String, default: "Proche" },
  },
  { timestamps: true }
);

export const EmergencyContactModel: Model<IEmergencyContact> =
  mongoose.models.EmergencyContact ||
  mongoose.model<IEmergencyContact>("EmergencyContact", EmergencyContactSchema);
