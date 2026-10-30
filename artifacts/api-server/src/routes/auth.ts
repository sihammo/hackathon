import { Router, type Request, type Response } from "express";
import { UserModel } from "../models";
import { SEED_USERS, isMongoConnected } from "../lib/db";
import { getPgUserByLogin, getPgUserByUid, isPgConnected } from "../lib/postgres";

const router = Router();
let memoryUsers = [...SEED_USERS];

// POST /api/auth/login
router.post("/login", async (req: Request, res: Response) => {
  try {
    const { username, password, phone } = req.body;
    const login = username || phone;

    if (!login) {
      return res.status(400).json({ error: "Username or phone is required" });
    }

    let user: any = null;

    // 1. Try Supabase PostgreSQL first
    try {
      user = await getPgUserByLogin(login);
    } catch {
      // Fall through to Mongo or memory
    }

    // 2. Try MongoDB if not found in PG
    if (!user && isMongoConnected()) {
      if (username) {
        user = await UserModel.findOne({
          username: username.toLowerCase().trim(),
        });
      } else if (phone) {
        user = await UserModel.findOne({ phone: phone.trim() });
      }
      if (user && user.toObject) user = user.toObject();
    }

    // 3. Fallback to seed memory
    if (!user) {
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

    const { password: _, ...userSafe } = user;

    return res.json({
      success: true,
      message: "Connexion réussie / تم تسجيل الدخول بنجاح",
      token: `slamtek-token-${userSafe.uid}-${Date.now()}`,
      database: isPgConnected() ? "supabase_postgresql" : isMongoConnected() ? "mongodb" : "in_memory",
      user: userSafe,
    });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me
router.get("/me", async (req: Request, res: Response) => {
  try {
    const uid = (req.query.uid as string) || "demo-user-1";

    let user: any = null;
    try {
      user = await getPgUserByUid(uid);
    } catch {
      // fallback
    }

    if (!user && isMongoConnected()) {
      const doc = await UserModel.findOne({ uid }).select("-password");
      if (doc) user = doc.toObject();
    }

    if (!user) {
      user = memoryUsers.find((u) => u.uid === uid);
    }

    if (!user) return res.status(404).json({ error: "User not found" });

    const { password: _, ...safe } = user;
    return res.json(safe);
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
