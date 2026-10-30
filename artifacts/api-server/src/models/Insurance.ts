import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IInsurancePartner extends Document {
  code: string;
  name: string;
  fullNameAr: string;
  commercialPlan: string;
  discountPercentage: number;
  contactEmail: string;
  contactPhone: string;
  activePolicies: number;
  claimsProcessed: number;
}

const InsurancePartnerSchema = new Schema<IInsurancePartner>(
  {
    code: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true },
    fullNameAr: { type: String, default: "" },
    commercialPlan: { type: String, default: "Formule Tiers + Slamtek IoT" },
    discountPercentage: { type: Number, default: 20 },
    contactEmail: { type: String, default: "contact@assurance.dz" },
    contactPhone: { type: String, default: "021000000" },
    activePolicies: { type: Number, default: 0 },
    claimsProcessed: { type: Number, default: 0 },
  },
  { timestamps: true }
);

export const InsurancePartnerModel: Model<IInsurancePartner> =
  mongoose.models.InsurancePartner ||
  mongoose.model<IInsurancePartner>("InsurancePartner", InsurancePartnerSchema);
