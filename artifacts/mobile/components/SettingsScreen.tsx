import { Feather } from '@expo/vector-icons';
import React, { useState } from 'react';
import { Pressable, StyleSheet, Switch, View } from 'react-native';
import { ActionButton, AppText, Card, DemoBanner, Heading, Input, Page, SectionTitle, WilayaPicker } from '@/components/AppUI';
import { useColors } from '@/hooks/useColors';
import { useApp } from '@/lib/app-context';
import { t } from '@/lib/i18n';

export default function SettingsScreen() {
  const {
    data,
    patchData,
    patchProfile,
    addContact,
    updateContact,
    deleteContact,
    signOut,
    captureLocation,
    locationError,
  } = useApp();
  const colors = useColors();
  const [name, setName] = useState(data.profile?.fullName ?? '');
  const [phone, setPhone] = useState(data.profile?.phone ?? '');
  const [contactName, setContactName] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formError, setFormError] = useState('');
  const [locating, setLocating] = useState(false);
  const copy = (key: string) => t(data.language, key);

  const saveContact = () => {
    if (contactName.trim().length < 2 || contactPhone.replace(/\D/g, '').length < 8) {
      setFormError('Saisissez un nom et un numéro de téléphone valide.');
      return;
    }
    if (editingId) {
      updateContact({ id: editingId, name: contactName.trim(), phone: contactPhone.trim() });
    } else {
      addContact({ name: contactName.trim(), phone: contactPhone.trim() });
    }
    setContactName('');
    setContactPhone('');
    setEditingId(null);
    setFormError('');
  };

  const beginEdit = (contact: { id: string; name: string; phone: string }) => {
    setEditingId(contact.id);
    setContactName(contact.name);
    setContactPhone(contact.phone);
    setFormError('');
  };

  return (
    <Page>
      <View style={{ gap: 6 }}>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.1 }}>COMPTE & PRÉFÉRENCES</AppText>
        <Heading>{copy('settings')}</Heading>
      </View>
      <DemoBanner />

      <Card>
        <SectionTitle>{copy('demoProfile')}</SectionTitle>
        <Input label={copy('name')} value={name} onChangeText={setName} testID="profile-name" />
        <Input label={copy('phone')} value={phone} onChangeText={setPhone} keyboardType="phone-pad" testID="profile-phone" />
        <WilayaPicker
          label={copy('wilaya')}
          value={data.profile?.wilaya ?? data.wilaya}
          onSelect={(wilaya) => patchProfile({ wilaya })}
        />
        <ActionButton
          label={copy('save')}
          icon="check"
          onPress={() => patchProfile({ fullName: name.trim(), phone: phone.trim() })}
          testID="save-profile"
        />
        <View style={styles.locationBlock}>
          <View style={{ flex: 1, gap: 3 }}>
            <AppText style={{ fontSize: 13, fontWeight: '700' }}>{copy('currentLocation')}</AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>
              {data.currentLocation
                ? `${data.currentLocation.latitude.toFixed(4)}, ${data.currentLocation.longitude.toFixed(4)}`
                : 'Position non enregistrée'}
            </AppText>
          </View>
          <Pressable
            testID="settings-location"
            accessibilityRole="button"
            accessibilityLabel={copy('getLocation')}
            disabled={locating}
            onPress={async () => {
              setLocating(true);
              await captureLocation();
              setLocating(false);
            }}
            style={[styles.smallIcon, { backgroundColor: colors.accent }]}
          >
            <Feather name="crosshair" size={18} color={colors.primary} />
          </Pressable>
        </View>
        {locationError ? (
          <View style={{ gap: 8 }}>
            <AppText style={{ color: colors.signal, fontSize: 12 }}>{locationError}</AppText>
            <ActionButton label="Réessayer" icon="refresh-cw" variant="outline" onPress={captureLocation} />
          </View>
        ) : null}
      </Card>

      <Card>
        <SectionTitle>{copy('language')}</SectionTitle>
        <View style={styles.languageRow}>
          {(['fr', 'ar'] as const).map((language) => {
            const active = data.language === language;
            return (
              <Pressable
                key={language}
                accessibilityRole="button"
                testID={`settings-language-${language}`}
                onPress={() => patchData({ language })}
                style={[
                  styles.languageOption,
                  { borderColor: active ? colors.primary : colors.border, backgroundColor: active ? colors.accent : colors.card },
                ]}
              >
                <AppText style={{ fontWeight: active ? '700' : '500', color: active ? colors.primary : colors.foreground }}>
                  {language === 'fr' ? 'Français' : 'العربية'}
                </AppText>
                {active ? <Feather name="check" size={16} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>
      </Card>

      <Card>
        <View style={styles.rowBetween}>
          <View style={{ flex: 1, gap: 4 }}>
            <AppText style={{ color: colors.deepNavy, fontSize: 16, fontWeight: '700' }}>{copy('testMode')}</AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 12, lineHeight: 17 }}>
              Activé par défaut. Les alertes restent simulées, même si vous désactivez ce réglage.
            </AppText>
          </View>
          <Switch
            testID="test-mode-switch"
            value={data.testMode}
            onValueChange={(testMode) => patchData({ testMode })}
            trackColor={{ false: colors.border, true: colors.success }}
            thumbColor={colors.card}
          />
        </View>
        {!data.testMode ? (
          <View style={[styles.warningBox, { backgroundColor: colors.warningSurface }]}>
            <Feather name="alert-triangle" size={16} color={colors.warning} />
            <AppText style={{ color: colors.warning, fontSize: 12, flex: 1, lineHeight: 17 }}>
              Le mode live n’est pas connecté. Aucun numéro réel n’est utilisé et aucun appel ne sera passé.
            </AppText>
          </View>
        ) : null}
      </Card>

      <View style={{ gap: 12 }}>
        <View style={styles.rowBetween}>
          <View style={{ flex: 1 }}>
            <SectionTitle>{copy('contacts')}</SectionTitle>
          </View>
          <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>{data.contacts.length}/5</AppText>
        </View>
        {data.contacts.map((contact) => (
          <View key={contact.id} style={[styles.contactRow, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <View style={[styles.contactAvatar, { backgroundColor: colors.accent }]}>
              <Feather name="user" size={17} color={colors.primary} />
            </View>
            <View style={{ flex: 1, gap: 3 }}>
              <AppText style={{ fontWeight: '700', fontSize: 14 }}>{contact.name}</AppText>
              <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>{contact.phone}</AppText>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={copy('editContact')}
              testID={`edit-contact-${contact.id}`}
              onPress={() => beginEdit(contact)}
              style={styles.actionIcon}
            >
              <Feather name="edit-2" size={16} color={colors.primary} />
            </Pressable>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={copy('deleteContact')}
              testID={`delete-contact-${contact.id}`}
              onPress={() => deleteContact(contact.id)}
              style={styles.actionIcon}
            >
              <Feather name="trash-2" size={16} color={colors.signal} />
            </Pressable>
          </View>
        ))}
        {data.contacts.length === 0 ? (
          <View style={[styles.emptyContacts, { borderColor: colors.border }]}>
            <Feather name="users" size={18} color={colors.mutedForeground} />
            <AppText style={{ color: colors.mutedForeground, fontSize: 13 }}>
              Aucun contact ajouté. Les coordonnées restent sur cet appareil.
            </AppText>
          </View>
        ) : null}
        {data.contacts.length < 5 || editingId ? (
          <Card>
            <AppText style={{ color: colors.deepNavy, fontSize: 15, fontWeight: '700' }}>
              {editingId ? copy('editContact') : copy('addContact')}
            </AppText>
            <Input label={copy('name')} value={contactName} onChangeText={setContactName} testID="contact-name" />
            <Input label={copy('phone')} value={contactPhone} onChangeText={setContactPhone} keyboardType="phone-pad" testID="contact-phone" />
            {formError ? <AppText style={{ color: colors.signal, fontSize: 12 }}>{formError}</AppText> : null}
            <View style={styles.rowBetween}>
              {editingId ? (
                <ActionButton
                  label={copy('cancel')}
                  variant="outline"
                  onPress={() => {
                    setEditingId(null);
                    setContactName('');
                    setContactPhone('');
                    setFormError('');
                  }}
                  style={{ flex: 1 }}
                />
              ) : null}
              <ActionButton label={copy('save')} icon="check" onPress={saveContact} testID="save-contact" style={{ flex: 1 }} />
            </View>
          </Card>
        ) : null}
      </View>

      <Card style={{ backgroundColor: colors.accent, borderColor: colors.accent }}>
        <View style={styles.rowBetween}>
          <Feather name="bluetooth" size={17} color={colors.primary} />
          <AppText style={{ flex: 1, color: colors.primary, fontWeight: '700', fontSize: 13 }}>
            {copy('liveUnavailable')}
          </AppText>
        </View>
      </Card>

      <ActionButton label={copy('signOut')} icon="log-out" variant="outline" onPress={signOut} testID="demo-signout" />
      <AppText style={{ color: colors.mutedForeground, fontSize: 11, textAlign: 'center' }}>
        {copy('testData')} · aucun mot de passe n’est enregistré
      </AppText>
    </Page>
  );
}

const styles = StyleSheet.create({
  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  locationBlock: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: 'transparent', paddingTop: 4, flexDirection: 'row', alignItems: 'center', gap: 12 },
  smallIcon: { width: 40, height: 40, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  languageRow: { flexDirection: 'row', gap: 10 },
  languageOption: { flex: 1, minHeight: 48, borderRadius: 14, borderWidth: 1, paddingHorizontal: 14, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  warningBox: { flexDirection: 'row', alignItems: 'flex-start', gap: 8, borderRadius: 12, padding: 11 },
  contactRow: { minHeight: 62, borderRadius: 16, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 9, flexDirection: 'row', alignItems: 'center', gap: 10 },
  contactAvatar: { width: 36, height: 36, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  actionIcon: { width: 34, height: 34, alignItems: 'center', justifyContent: 'center' },
  emptyContacts: { borderWidth: 1, borderStyle: 'dashed', borderRadius: 15, minHeight: 66, padding: 14, flexDirection: 'row', alignItems: 'center', gap: 10 },
});
