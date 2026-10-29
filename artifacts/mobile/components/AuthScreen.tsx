import { Feather } from '@expo/vector-icons';
import { router, Redirect } from 'expo-router';
import React, { useState } from 'react';
import { Image, Pressable, StyleSheet, View } from 'react-native';
import { KeyboardAwareScrollViewCompat } from '@/components/KeyboardAwareScrollViewCompat';
import { ActionButton, AppText, DemoBanner, FormError, Input, LoadingScreen, WilayaPicker } from '@/components/AppUI';
import { useApp } from '@/lib/app-context';
import { t } from '@/lib/i18n';
import { useColors } from '@/hooks/useColors';

export default function AuthScreen() {
  const { data, ready, storageError, startDemo, createProfile, patchData } = useApp();
  const colors = useColors();
  const [creating, setCreating] = useState(false);
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [phone, setPhone] = useState('');
  const [wilaya, setWilaya] = useState('Alger');
  const [error, setError] = useState('');

  if (!ready) return <LoadingScreen />;
  if (data.profile) {
    return <Redirect href={data.role === 'admin' ? '/admin' : '/(tabs)'} />;
  }

  const enterDemo = (role: 'user' | 'admin') => {
    setError('');
    const allowed = startDemo(role, username);
    if (!allowed) {
      setError('Ce profil de démonstration est désactivé par l’administrateur local.');
      return;
    }
    router.replace(role === 'admin' ? '/admin' : '/(tabs)');
  };

  const submitProfile = () => {
    const cleanName = fullName.trim();
    const cleanUsername = username.trim();
    const cleanPhone = phone.trim();
    if (cleanName.length < 2 || cleanUsername.length < 3 || cleanPhone.replace(/\D/g, '').length < 8) {
      setError('Ajoutez un nom, un identifiant de 3 caractères et un numéro valide.');
      return;
    }
    createProfile({ fullName: cleanName, username: cleanUsername, phone: cleanPhone, wilaya });
    router.replace('/(tabs)');
  };

  return (
    <KeyboardAwareScrollViewCompat
      style={{ flex: 1, backgroundColor: colors.background, direction: data.language === 'ar' ? 'rtl' : 'ltr' }}
      contentContainerStyle={[
        styles.content,
        { paddingTop: 24, paddingBottom: 34, backgroundColor: colors.background, direction: data.language === 'ar' ? 'rtl' : 'ltr' },
      ]}
      bottomOffset={32}
      keyboardShouldPersistTaps="handled"
    >
      <View style={styles.brand}>
        <Image source={require('../assets/images/icon.png')} style={styles.logo} />
        <View style={{ flex: 1, gap: 4 }}>
          <AppText style={{ fontSize: 13, color: colors.mutedForeground, fontWeight: '700', letterSpacing: 1.6 }}>
            SOLVEX
          </AppText>
          <AppText style={{ fontSize: 31, fontWeight: '800', letterSpacing: -1.1, color: colors.deepNavy }}>
            Alert
          </AppText>
        </View>
        <View style={[styles.languageChip, { backgroundColor: colors.card, borderColor: colors.border }]}>
          <Pressable
            accessibilityRole="button"
            testID="language-fr"
            onPress={() => patchData({ language: 'fr' })}
          >
            <AppText style={{ fontSize: 12, fontWeight: data.language === 'fr' ? '800' : '500', color: data.language === 'fr' ? colors.primary : colors.mutedForeground }}>FR</AppText>
          </Pressable>
          <View style={{ width: 1, height: 14, backgroundColor: colors.border }} />
          <Pressable
            accessibilityRole="button"
            testID="language-ar"
            onPress={() => patchData({ language: 'ar' })}
          >
            <AppText style={{ fontSize: 12, fontWeight: data.language === 'ar' ? '800' : '500', color: data.language === 'ar' ? colors.primary : colors.mutedForeground }}>ع</AppText>
          </Pressable>
        </View>
      </View>

      <View style={{ gap: 8 }}>
        <AppText style={{ fontSize: 23, fontWeight: '700', color: colors.deepNavy, lineHeight: 30 }}>
          {t(data.language, 'welcome')}
        </AppText>
        <AppText style={{ color: colors.mutedForeground, fontSize: 14, lineHeight: 21 }}>
          Détection d’accident, contacts et historique — dans une démo locale.
        </AppText>
      </View>

      <DemoBanner />
      {storageError ? (
        <FormError>Le stockage local est indisponible. Les changements de cette session ne seront pas conservés.</FormError>
      ) : null}

      {creating ? (
        <View style={{ gap: 14 }}>
          <View style={styles.sectionHeading}>
            <View style={[styles.headingIcon, { backgroundColor: colors.accent }]}>
              <Feather name="user-plus" size={18} color={colors.primary} />
            </View>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText style={{ color: colors.deepNavy, fontSize: 17, fontWeight: '700' }}>
                {t(data.language, 'createAccount')}
              </AppText>
              <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>
                Profil enregistré sur cet appareil uniquement.
              </AppText>
            </View>
          </View>
          <Input label={t(data.language, 'name')} value={fullName} onChangeText={setFullName} autoCapitalize="words" testID="signup-name" />
          <Input label={t(data.language, 'username')} value={username} onChangeText={setUsername} autoCapitalize="none" testID="signup-username" />
          <Input label={t(data.language, 'phone')} value={phone} onChangeText={setPhone} keyboardType="phone-pad" testID="signup-phone" />
          <WilayaPicker label={t(data.language, 'wilaya')} value={wilaya} onSelect={setWilaya} />
          <AppText style={{ color: colors.warning, fontSize: 12, lineHeight: 17 }}>
            Le mot de passe et Firebase seront ajoutés avec votre projet. Aucun mot de passe n’est demandé ni stocké dans cette démo.
          </AppText>
          {error ? <FormError>{error}</FormError> : null}
          <ActionButton label={t(data.language, 'save')} icon="check" onPress={submitProfile} testID="create-profile" />
          <ActionButton label={t(data.language, 'cancel')} variant="outline" onPress={() => setCreating(false)} />
        </View>
      ) : (
        <View style={{ gap: 14 }}>
          <Input
            label={t(data.language, 'username')}
            value={username}
            onChangeText={setUsername}
            placeholder="ex. samira.b"
            autoCapitalize="none"
            testID="login-username"
          />
          {error ? <FormError>{error}</FormError> : null}
          <ActionButton
            label={t(data.language, 'signInUser')}
            icon="arrow-right"
            onPress={() => enterDemo('user')}
            testID="demo-user-login"
          />
          <ActionButton
            label={t(data.language, 'signInAdmin')}
            icon="grid"
            variant="secondary"
            onPress={() => enterDemo('admin')}
            testID="demo-admin-login"
          />
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              setError('');
              setCreating(true);
            }}
            style={{ alignItems: 'center', paddingVertical: 10 }}
          >
            <AppText style={{ color: colors.primary, fontWeight: '700', fontSize: 14 }}>
              {t(data.language, 'register')}
            </AppText>
          </Pressable>
          <View style={[styles.note, { borderColor: colors.border, backgroundColor: colors.card }]}>
            <Feather name="info" size={16} color={colors.primary} />
            <AppText style={{ color: colors.mutedForeground, flex: 1, fontSize: 12, lineHeight: 17 }}>
              Connexion de démonstration uniquement. Les profils et réglages restent sur cet appareil; les rôles Firebase ne sont pas encore vérifiés.
            </AppText>
          </View>
        </View>
      )}
    </KeyboardAwareScrollViewCompat>
  );
}

const styles = StyleSheet.create({
  content: { flexGrow: 1, paddingHorizontal: 22, gap: 22 },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 13 },
  logo: { width: 58, height: 58, borderRadius: 18 },
  languageChip: { flexDirection: 'row', alignItems: 'center', gap: 11, borderWidth: 1, borderRadius: 99, paddingHorizontal: 12, paddingVertical: 9 },
  sectionHeading: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 2 },
  headingIcon: { width: 40, height: 40, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  note: { flexDirection: 'row', alignItems: 'flex-start', gap: 9, borderRadius: 14, borderWidth: 1, padding: 12 },
});
