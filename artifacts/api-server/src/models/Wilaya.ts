import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IWilaya extends Document {
  code: number;
  name: string;
  nameAr: string;
  police: string;
  civilProtection: string;
  gendarmerie: string;
}

const WilayaSchema = new Schema<IWilaya>(
  {
    code: { type: Number, required: true, unique: true, index: true },
    name: { type: String, required: true },
    nameAr: { type: String, default: "" },
    police: { type: String, default: "17" },
    civilProtection: { type: String, default: "14" },
    gendarmerie: { type: String, default: "1055" },
  },
  { timestamps: true }
);

export const WilayaModel: Model<IWilaya> =
  mongoose.models.Wilaya || mongoose.model<IWilaya>("Wilaya", WilayaSchema);
