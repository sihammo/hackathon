import mongoose, { Schema, type Document, type Model } from "mongoose";

export interface IUser extends Document {
  uid: string;
  fullName: string;
  username: string;
  password?: string;
  phone: string;
  wilayaCode: number;
  role: "admin" | "user" | "insurance" | "police" | "civil_protection";
  disabled: boolean;
  vehicleType: "car" | "motorcycle" | "truck";
  testMode: boolean;
  testPhoneNumber: string;
  avatarUrl?: string;
  insuranceCompany?: string;
  policyNumber?: string;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    uid: { type: String, required: true, unique: true, index: true },
    fullName: { type: String, required: true },
    username: { type: String, required: true, unique: true, index: true, lowercase: true, trim: true },
    password: { type: String, default: "slamtek123" },
    phone: { type: String, required: true, index: true },
    wilayaCode: { type: Number, required: true, default: 16 },
    role: {
      type: String,
      enum: ["admin", "user", "insurance", "police", "civil_protection"],
      default: "user",
      index: true,
    },
    disabled: { type: Boolean, default: false },
    vehicleType: {
      type: String,
      enum: ["car", "motorcycle", "truck"],
      default: "car",
    },
    testMode: { type: Boolean, default: true },
    testPhoneNumber: { type: String, default: "0555999888" },
    avatarUrl: { type: String },
    insuranceCompany: { type: String, default: "CAAT" },
    policyNumber: { type: String },
  },
  { timestamps: true }
);

export const UserModel: Model<IUser> =
  mongoose.models.User || mongoose.model<IUser>("User", UserSchema);
