import { Feather } from '@expo/vector-icons';
import { Redirect, useLocalSearchParams, router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Svg, { Circle, Line, Rect } from 'react-native-svg';
import { ActionButton, AppText, Badge, Card, Heading, Page } from '@/components/AppUI';
import { useColors } from '@/hooks/useColors';
import { useApp, type AlertRecord, type AlertStage, type ResponseService } from '@/lib/app-context';
import { t } from '@/lib/i18n';

const stages: AlertStage[] = [
  'Test recorded',
  'Test received',
  'Test team dispatched',
  'Test arrived',
  'Test resolved',
];

export default function AlertDetailsScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { data } = useApp();
  const colors = useColors();
  if (!data.profile || data.role !== 'admin') return <Redirect href="/" />;
  const alert = data.alerts.find((item) => item.id === id);

  if (!alert) {
    return (
      <Page>
        <Heading>{t(data.language, 'alerts')}</Heading>
        <Card style={{ gap: 12 }}>
          <AppText style={{ color: colors.mutedForeground }}>
            Cette alerte locale n’existe plus sur cet appareil.
          </AppText>
          <ActionButton label="Retour au tableau de bord" icon="arrow-left" onPress={() => router.back()} />
        </Card>
      </Page>
    );
  }

  const date = new Date(alert.createdAt);
  return (
    <Page>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Retour"
          onPress={() => router.back()}
          style={[styles.back, { borderColor: colors.border, backgroundColor: colors.card }]}
        >
          <Feather name="arrow-left" size={18} color={colors.deepNavy} />
        </Pressable>
        <View style={{ flex: 1, gap: 4 }}>
          <AppText style={{ color: colors.mutedForeground, fontSize: 11, fontWeight: '700', letterSpacing: 1 }}>
            ALERTE DE TEST
          </AppText>
          <Heading>{alert.wilaya}</Heading>
        </View>
        <Badge tone="warning">{alert.vehicleType === 'car' ? 'Voiture' : 'Moto'}</Badge>
      </View>

      <Card style={{ gap: 7 }}>
        <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 15 }}>
          {date.toLocaleDateString('fr-FR')} · {date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
        </AppText>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>
          {alert.latitude !== null && alert.longitude !== null
            ? `${alert.latitude.toFixed(6)}, ${alert.longitude.toFixed(6)}`
            : 'Aucune coordonnée GPS enregistrée.'}
        </AppText>
      </Card>

      <Card style={{ gap: 11 }}>
        <AppText style={{ color: colors.deepNavy, fontSize: 15, fontWeight: '700' }}>Position de l’incident</AppText>
        <View style={[styles.map, { backgroundColor: colors.mapSurface }]}>
          <Svg width="100%" height="100%" viewBox="0 0 320 210">
            <Rect width="320" height="210" fill={colors.mapSurface} />
            {[35, 76, 117, 158, 199].map((y) => (
              <Line key={`h${y}`} x1="0" y1={y} x2="320" y2={y + 9} stroke={colors.mapRoad} strokeWidth="3" />
            ))}
            {[30, 82, 134, 186, 238, 290].map((x) => (
              <Line key={`v${x}`} x1={x} y1="0" x2={x - 14} y2="210" stroke={colors.mapRoad} strokeWidth="2" />
            ))}
            <Circle cx="160" cy="105" r="15" fill={colors.dangerSurface} />
            <Circle cx="160" cy="105" r="7" fill={colors.deepNavy} stroke={colors.card} strokeWidth="3" />
          </Svg>
          <View style={[styles.mapLabel, { backgroundColor: colors.card }]}>
            <Feather name="map-pin" size={13} color={colors.primary} />
            <AppText style={{ fontSize: 10, fontWeight: '700' }}>
              {alert.latitude !== null ? 'Coordonnées GPS capturées' : 'Aucune position capturée'}
            </AppText>
          </View>
        </View>
        <AppText style={{ color: colors.mutedForeground, fontSize: 11, lineHeight: 16 }}>
          Aperçu schématique, non destiné à la navigation. Une carte routière nécessite un fournisseur de cartes connecté.
        </AppText>
      </Card>

      <Card style={{ gap: 13 }}>
        <AppText style={{ color: colors.deepNavy, fontSize: 15, fontWeight: '700' }}>Suivi des services (simulation)</AppText>
        <ServiceTimeline alert={alert} service="police" label="Police" />
        <View style={{ height: 1, backgroundColor: colors.border }} />
        <ServiceTimeline alert={alert} service="civilProtection" label="Protection civile" />
      </Card>

      <ActionButton label="Retour au tableau de bord" icon="arrow-left" variant="outline" onPress={() => router.back()} />
    </Page>
  );
}

function ServiceTimeline({
  alert,
  service,
  label,
}: {
  alert: AlertRecord;
  service: ResponseService;
  label: string;
}) {
  const colors = useColors();
  const status = alert.serviceStatus?.[service] ?? alert.stage;
  const timestamps =
    alert.serviceStatusTimestamps?.[service] ?? alert.responseTimestamps;
  const current = stages.indexOf(status);
  const arrivedAt = timestamps['Test arrived'];
  const responseMinutes = arrivedAt
    ? Math.max(0, (new Date(arrivedAt).getTime() - new Date(alert.createdAt).getTime()) / 60000)
    : null;
  return (
    <View style={{ gap: 10 }}>
      <View style={styles.serviceHeader}>
        <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 13 }}>{label}</AppText>
        <Badge tone="warning">{status.replace('Test ', '')}</Badge>
      </View>
      {stages.map((stage, index) => {
        const stamp = timestamps[stage];
        const reached = index <= current && Boolean(stamp);
        return (
          <View key={`${service}-${stage}`} style={styles.timelineRow}>
            <View
              style={[
                styles.timelineDot,
                { backgroundColor: reached ? colors.primary : colors.border },
              ]}
            />
            <AppText
              style={{
                flex: 1,
                color: reached ? colors.deepNavy : colors.mutedForeground,
                fontSize: 11,
                fontWeight: reached ? '700' : '400',
              }}
            >
              {stage.replace('Test ', '')}
            </AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 10 }}>
              {stamp ? new Date(stamp).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '—'}
            </AppText>
          </View>
        );
      })}
      <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
        Délai jusqu’à l’arrivée · {responseMinutes === null ? 'non disponible' : `${responseMinutes.toFixed(1)} min`}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  back: { width: 42, height: 42, borderWidth: 1, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  map: { height: 210, borderRadius: 17, overflow: 'hidden' },
  mapLabel: { position: 'absolute', left: 9, top: 9, borderRadius: 11, paddingHorizontal: 9, paddingVertical: 7, flexDirection: 'row', alignItems: 'center', gap: 5 },
  serviceHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  timelineRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  timelineDot: { width: 8, height: 8, borderRadius: 4 },
});
