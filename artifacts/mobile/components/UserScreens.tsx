import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Svg, { Circle, Line, Rect } from 'react-native-svg';
import { ActionButton, AppText, Badge, Card, DemoBanner, Heading, Page, SectionTitle } from '@/components/AppUI';
import { useColors } from '@/hooks/useColors';
import { useApp, type AlertRecord, type VehicleType } from '@/lib/app-context';
import { t } from '@/lib/i18n';

export function HomeScreen() {
  const { data, patchData, captureLocation, locationError } = useApp();
  const colors = useColors();
  const [locating, setLocating] = useState(false);
  const copy = (key: string) => t(data.language, key);

  const locate = async () => {
    setLocating(true);
    await captureLocation();
    setLocating(false);
  };

  return (
    <Page>
      <View style={styles.header}>
        <View style={{ flex: 1, gap: 5 }}>
          <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.4 }}>
            SOLVEX ALERT
          </AppText>
          <Heading>{copy('home')}</Heading>
          <AppText style={{ color: colors.mutedForeground, fontSize: 14 }}>
            Bonjour, {data.profile?.fullName ?? 'Conducteur'}
          </AppText>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={copy('settings')}
          onPress={() => router.push('/(tabs)/settings')}
          style={[styles.roundIcon, { backgroundColor: colors.card, borderColor: colors.border }]}
        >
          <Feather name="settings" size={19} color={colors.deepNavy} />
        </Pressable>
      </View>

      <DemoBanner />

      <Card style={{ backgroundColor: colors.deepNavy, borderColor: colors.deepNavy, padding: 20 }}>
        <View style={styles.rowBetween}>
          <View style={{ gap: 6, flex: 1 }}>
            <AppText style={{ color: colors.primaryForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.1 }}>
              {copy('sensor').toUpperCase()}
            </AppText>
            <AppText style={{ color: colors.primaryForeground, fontSize: 21, fontWeight: '700' }}>
              {copy('demoDevice')}
            </AppText>
          </View>
          <View style={[styles.signalOrb, { backgroundColor: data.deviceConnected ? colors.success : colors.signal }]}>
            <Feather name={data.deviceConnected ? 'bluetooth' : 'bluetooth'} size={21} color={colors.primaryForeground} />
          </View>
        </View>
        <View style={styles.rowBetween}>
          <Badge tone={data.deviceConnected ? 'success' : 'warning'}>
            {copy(data.deviceConnected ? 'connected' : 'disconnected')}
          </Badge>
          <AppText style={{ color: colors.primaryForeground, opacity: 0.75, fontSize: 12 }}>
            {data.vehicleType === 'car' ? 'Profil voiture · seuil élevé' : 'Profil moto · impact + inclinaison'}
          </AppText>
        </View>
        <ActionButton
          label={copy(data.deviceConnected ? 'disconnectDevice' : 'pairDevice')}
          icon={data.deviceConnected ? 'bluetooth' : 'bluetooth'}
          variant="outline"
          onPress={() => patchData({ deviceConnected: !data.deviceConnected })}
          testID="pair-demo-device"
          style={{ backgroundColor: colors.card }}
        />
        <AppText style={{ color: colors.primaryForeground, opacity: 0.72, fontSize: 11, lineHeight: 16 }}>
          Connexion simulée. L’ESP32 et le BLE réel ne sont pas activés dans cet aperçu.
        </AppText>
      </Card>

      <View style={{ gap: 12 }}>
        <SectionTitle>{copy('vehicle')}</SectionTitle>
        <View style={styles.vehicleRow}>
          {(['car', 'motorcycle'] as VehicleType[]).map((type) => {
            const active = data.vehicleType === type;
            return (
              <Pressable
                key={type}
                testID={`vehicle-${type}`}
                accessibilityRole="button"
                onPress={() => patchData({ vehicleType: type })}
                style={[
                  styles.vehicleCard,
                  {
                    backgroundColor: active ? colors.accent : colors.card,
                    borderColor: active ? colors.primary : colors.border,
                  },
                ]}
              >
                <Feather name={type === 'car' ? 'truck' : 'navigation'} size={19} color={active ? colors.primary : colors.mutedForeground} />
                <AppText style={{ fontSize: 14, fontWeight: '700', color: active ? colors.primary : colors.foreground }}>
                  {copy(type)}
                </AppText>
                {active ? <Feather name="check-circle" size={17} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>
      </View>

      <Card>
        <View style={styles.rowBetween}>
          <View style={{ flex: 1, gap: 5 }}>
            <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700' }}>{copy('location').toUpperCase()}</AppText>
            <AppText style={{ color: colors.deepNavy, fontSize: 17, fontWeight: '700' }}>
              {data.wilaya}
            </AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>
              {data.currentLocation
                ? `${data.currentLocation.latitude.toFixed(4)}, ${data.currentLocation.longitude.toFixed(4)}`
                : copy('locationUnavailable')}
            </AppText>
          </View>
          <View style={[styles.locationIcon, { backgroundColor: colors.accent }]}>
            <Feather name="map-pin" size={20} color={colors.primary} />
          </View>
        </View>
        <ActionButton
          label={locating ? 'Localisation…' : copy('getLocation')}
          icon="crosshair"
          variant="secondary"
          disabled={locating}
          onPress={locate}
          testID="capture-location"
        />
        {locationError ? <AppText style={{ color: colors.signal, fontSize: 12 }}>{locationError}</AppText> : null}
      </Card>

      <Card style={{ gap: 12 }}>
        <View style={styles.rowBetween}>
          <View style={{ gap: 5, flex: 1 }}>
            <AppText style={{ fontSize: 17, color: colors.deepNavy, fontWeight: '700' }}>Tout est prêt ?</AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 13, lineHeight: 18 }}>
              Testez le compte à rebours sans contacter de service.
            </AppText>
          </View>
          <View style={[styles.testMark, { backgroundColor: colors.dangerSurface }]}>
            <Feather name="alert-triangle" size={20} color={colors.signal} />
          </View>
        </View>
        <ActionButton
          label={copy('startTest')}
          icon="alert-circle"
          variant="danger"
          onPress={() => router.push('/emergency')}
          testID="start-test-alert"
        />
        <AppText style={{ color: colors.mutedForeground, fontSize: 11, lineHeight: 16 }}>
          Ce test ne déclenche jamais de SMS, d’appel ou d’envoi vers les secours.
        </AppText>
      </Card>

      <View style={styles.rowBetween}>
        <SectionTitle>{copy('savedAlerts')}</SectionTitle>
        <Pressable accessibilityRole="button" onPress={() => router.push('/(tabs)/history')}>
          <AppText style={{ color: colors.primary, fontWeight: '700', fontSize: 13 }}>Tout voir</AppText>
        </Pressable>
      </View>
      <View style={[styles.miniStat, { backgroundColor: colors.card, borderColor: colors.border }]}>
        <View style={[styles.miniIcon, { backgroundColor: colors.accent }]}>
          <Feather name="activity" size={17} color={colors.primary} />
        </View>
        <View style={{ flex: 1 }}>
          <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 15 }}>{data.alerts.length}</AppText>
          <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>événement(s) test sur cet appareil</AppText>
        </View>
        <Feather name="chevron-right" size={18} color={colors.mutedForeground} />
      </View>
    </Page>
  );
}

export function MapScreen() {
  const { data } = useApp();
  const colors = useColors();
  const width = 300;
  const height = 350;
  const points = useMemo(() => data.alerts.filter((alert) => alert.latitude !== null && alert.longitude !== null), [data.alerts]);
  return (
    <Page>
      <View style={{ gap: 6 }}>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.2 }}>SOLVEX / TERRAIN</AppText>
        <Heading>{t(data.language, 'map')}</Heading>
        <AppText style={{ color: colors.mutedForeground, fontSize: 13, lineHeight: 19 }}>
          Points noirs : coordonnées réelles capturées pendant les alertes de test sur cet appareil.
        </AppText>
      </View>
      <Card style={{ padding: 12 }}>
        <View style={{ overflow: 'hidden', borderRadius: 20, alignSelf: 'center' }}>
          <Svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
            <Rect x="0" y="0" width={width} height={height} fill={colors.mapSurface} />
            {[35, 82, 129, 176, 223, 270].map((y) => (
              <Line key={`h${y}`} x1="0" y1={y} x2={width} y2={y + 12} stroke={colors.mapRoad} strokeWidth={y % 2 ? 4 : 2} />
            ))}
            {[35, 87, 139, 191, 243, 295].map((x) => (
              <Line key={`v${x}`} x1={x} y1="0" x2={x - 15} y2={height} stroke={colors.mapRoad} strokeWidth={x % 2 ? 3 : 1.5} />
            ))}
            <Line x1="0" y1="277" x2={width} y2="113" stroke={colors.mapAccent} strokeWidth="6" />
            {points.map((point) => (
              <Circle
                key={point.id}
                cx={Math.max(13, Math.min(width - 13, ((point.longitude! + 8.7) / 20.7) * width))}
                cy={Math.max(13, Math.min(height - 13, ((37 - point.latitude!) / 18.1) * height))}
                r="7"
                fill={colors.deepNavy}
                stroke={colors.card}
                strokeWidth="3"
              />
            ))}
          </Svg>
          <View style={[styles.mapLabel, { backgroundColor: colors.card }]}>
            <Feather name="map-pin" size={14} color={colors.primary} />
            <AppText style={{ fontSize: 11, fontWeight: '700' }}>Algérie · vue schématique</AppText>
          </View>
        </View>
        <View style={styles.rowBetween}>
          <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>Points cartographiés</AppText>
          <Badge>{points.length}</Badge>
        </View>
      </Card>
      {points.length === 0 ? (
        <Card style={{ alignItems: 'center', paddingVertical: 26 }}>
          <View style={[styles.emptyIcon, { backgroundColor: colors.accent }]}>
            <Feather name="map" size={22} color={colors.primary} />
          </View>
          <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 16 }}>Aucun point enregistré</AppText>
          <AppText style={{ color: colors.mutedForeground, fontSize: 13, textAlign: 'center', lineHeight: 19 }}>
            Autorisez la position puis lancez un test. Les coordonnées apparaîtront ici.
          </AppText>
        </Card>
      ) : (
        <Card>
          <SectionTitle>Zones observées</SectionTitle>
          {points.map((point) => <AlertRow key={point.id} alert={point} />)}
        </Card>
      )}
      <AppText style={{ color: colors.mutedForeground, fontSize: 11, lineHeight: 16 }}>
        Carte illustrative, non destinée à la navigation. Les événements restent locaux à cette démo.
      </AppText>
    </Page>
  );
}

export function HistoryScreen() {
  const { data } = useApp();
  const colors = useColors();
  const [period, setPeriod] = useState<'all' | 'week' | 'month'>('all');
  const threshold = period === 'week' ? 7 : period === 'month' ? 30 : Infinity;
  const filtered = data.alerts.filter((alert) => Date.now() - new Date(alert.createdAt).getTime() <= threshold * 86400000);
  return (
    <Page>
      <View style={{ gap: 6 }}>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.2 }}>ACTIVITÉ LOCALE</AppText>
        <Heading>{t(data.language, 'history')}</Heading>
        <AppText style={{ color: colors.mutedForeground, fontSize: 13 }}>
          {data.alerts.length} événement(s) conservé(s) sur cet appareil
        </AppText>
      </View>
      <View style={styles.filterRow}>
        {(['all', 'week', 'month'] as const).map((key) => {
          const active = period === key;
          const label = t(data.language, key === 'all' ? 'all' : key === 'week' ? 'thisWeek' : 'thisMonth');
          return (
            <Pressable
              key={key}
              accessibilityRole="button"
              onPress={() => setPeriod(key)}
              style={[styles.filterPill, { backgroundColor: active ? colors.deepNavy : colors.card, borderColor: active ? colors.deepNavy : colors.border }]}
            >
              <AppText style={{ color: active ? colors.primaryForeground : colors.mutedForeground, fontWeight: '700', fontSize: 12 }}>{label}</AppText>
            </Pressable>
          );
        })}
      </View>
      {filtered.length === 0 ? (
        <Card style={{ alignItems: 'center', paddingVertical: 30 }}>
          <View style={[styles.emptyIcon, { backgroundColor: colors.accent }]}>
            <Feather name="activity" size={21} color={colors.primary} />
          </View>
          <AppText style={{ fontSize: 16, fontWeight: '700', color: colors.deepNavy }}>{t(data.language, 'noAlerts')}</AppText>
          <AppText style={{ color: colors.mutedForeground, textAlign: 'center', fontSize: 13, lineHeight: 19 }}>
            {t(data.language, 'noAlertsHint')}
          </AppText>
          <ActionButton label={t(data.language, 'startTest')} icon="alert-circle" variant="danger" onPress={() => router.push('/emergency')} />
        </Card>
      ) : (
        <Card style={{ gap: 0 }}>
          {filtered.map((alert, index) => (
            <View key={alert.id}>
              {index > 0 ? <View style={{ height: 1, backgroundColor: colors.border, marginVertical: 13 }} /> : null}
              <AlertRow alert={alert} />
            </View>
          ))}
        </Card>
      )}
      <DemoBanner />
    </Page>
  );
}

function AlertRow({ alert }: { alert: AlertRecord }) {
  const colors = useColors();
  const when = new Date(alert.createdAt);
  return (
    <View style={styles.alertRow}>
      <View style={[styles.alertIcon, { backgroundColor: colors.dangerSurface }]}>
        <Feather name="alert-triangle" size={17} color={colors.signal} />
      </View>
      <View style={{ flex: 1, gap: 4 }}>
        <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 14 }}>Test · {alert.wilaya}</AppText>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>
          {when.toLocaleDateString('fr-FR')} · {when.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })} · {alert.vehicleType === 'car' ? 'Voiture' : 'Moto'}
        </AppText>
        {alert.latitude !== null && alert.longitude !== null ? (
          <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
            {alert.latitude.toFixed(4)}, {alert.longitude.toFixed(4)}
          </AppText>
        ) : null}
      </View>
      <Badge tone="warning">{alert.stage.replace('Test ', '')}</Badge>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  roundIcon: { width: 44, height: 44, borderRadius: 15, alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  signalOrb: { width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center' },
  vehicleRow: { flexDirection: 'row', gap: 10 },
  vehicleCard: { flex: 1, minHeight: 62, borderWidth: 1, borderRadius: 17, paddingHorizontal: 12, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  locationIcon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  testMark: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  miniStat: { minHeight: 64, borderWidth: 1, borderRadius: 16, padding: 12, flexDirection: 'row', alignItems: 'center', gap: 12 },
  miniIcon: { width: 36, height: 36, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  mapLabel: { position: 'absolute', top: 10, left: 10, paddingVertical: 8, paddingHorizontal: 10, borderRadius: 12, flexDirection: 'row', alignItems: 'center', gap: 6 },
  emptyIcon: { width: 48, height: 48, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  filterRow: { flexDirection: 'row', gap: 8 },
  filterPill: { borderWidth: 1, borderRadius: 99, paddingVertical: 9, paddingHorizontal: 14 },
  alertRow: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  alertIcon: { width: 38, height: 38, alignItems: 'center', justifyContent: 'center', borderRadius: 13 },
});
