import { Router, type Request, type Response } from "express";
import { UserModel } from "../models";
import { SEED_USERS, isMongoConnected } from "../lib/db";

const router = Router();

// In-memory fallback if Mongo not yet connected
let memoryUsers = [...SEED_USERS];

// POST /api/auth/login
router.post("/login", async (req: Request, res: Response) => {
  try {
    const { username, password, phone } = req.body;

    if (!username && !phone) {
      return res.status(400).json({ error: "Username or phone is required" });
    }

    let user: any = null;

    if (isMongoConnected()) {
      if (username) {
        user = await UserModel.findOne({
          username: username.toLowerCase().trim(),
        });
      } else if (phone) {
        user = await UserModel.findOne({ phone: phone.trim() });
      }
    } else {
      user = memoryUsers.find(
        (u) =>
          (username && u.username.toLowerCase() === username.toLowerCase().trim()) ||
          (phone && u.phone === phone.trim())
      );
    }

    if (!user) {
      return res.status(401).json({ error: "Compte non trouvé / الحساب غير موجود" });
    }

    if (password && user.password && user.password !== password) {
      return res.status(401).json({ error: "Mot de passe incorrect / كلمة المرور خاطئة" });
    }

    if (user.disabled) {
      return res.status(403).json({ error: "Compte désactivé / الحساب معطل" });
    }

    // Return sanitized user object
    const userObj = user.toObject ? user.toObject() : { ...user };
    delete userObj.password;

    return res.json({
      success: true,
      message: "Connexion réussie / تم تسجيل الدخول بنجاح",
      token: `slamtek-token-${userObj.uid}-${Date.now()}`,
      user: userObj,
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me
router.get("/me", async (req: Request, res: Response) => {
  const uid = (req.query.uid as string) || "demo-user-1";

  if (isMongoConnected()) {
    const user = await UserModel.findOne({ uid });
    if (!user) return res.status(404).json({ error: "User not found" });
    const userObj = user.toObject();
    delete (userObj as any).password;
    return res.json(userObj);
  }

  const user = memoryUsers.find((u) => u.uid === uid);
  if (!user) return res.status(404).json({ error: "User not found" });
  const { password, ...safe } = user;
  return res.json(safe);
});

// POST /api/auth/register
router.post("/register", async (req: Request, res: Response) => {
  try {
    const { fullName, username, password, phone, wilayaCode, vehicleType, insuranceCompany } = req.body;

    if (!fullName || !username || !phone) {
      return res.status(400).json({ error: "Informations incomplètes" });
    }

    const uid = `u-${Date.now()}`;
    const newUser = {
      uid,
      fullName,
      username: username.toLowerCase().trim(),
      password: password || "slamtek123",
      phone: phone.trim(),
      wilayaCode: Number(wilayaCode) || 16,
      role: "user" as const,
      disabled: false,
      vehicleType: vehicleType || "car",
      testMode: true,
      testPhoneNumber: phone,
      insuranceCompany: insuranceCompany || "CAAT",
      avatarUrl: "/assets/images/karim.jpg",
    };

    if (isMongoConnected()) {
      const created = await UserModel.create(newUser);
      const userObj = created.toObject();
      delete (userObj as any).password;
      return res.status(201).json({ success: true, user: userObj });
    }

    memoryUsers.push(newUser as any);
    const { password: _, ...safe } = newUser;
    return res.status(201).json({ success: true, user: safe });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
