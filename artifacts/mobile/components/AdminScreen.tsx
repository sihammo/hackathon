import { Feather } from '@expo/vector-icons';
import { Redirect, router } from 'expo-router';
import React, { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { ActionButton, AppText, Badge, Card, DemoBanner, Heading, Input, Page, SectionTitle, WilayaPicker } from '@/components/AppUI';
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

export default function AdminScreen() {
  const {
    data,
    updateAlertStage,
    toggleUserDisabled,
    upsertWilayaNumbers,
    deleteWilayaNumbers,
    signOut,
  } = useApp();
  const colors = useColors();
  const [alertFilter, setAlertFilter] = useState<'all' | 'car' | 'motorcycle'>('all');
  const [alertPeriod, setAlertPeriod] = useState<'all' | 'week' | 'month'>('all');
  const [alertWilaya, setAlertWilaya] = useState('all');
  const [alertStage, setAlertStage] = useState<'all' | AlertStage>('all');
  const [userQuery, setUserQuery] = useState('');
  const [numberWilaya, setNumberWilaya] = useState('Alger');
  const [police, setPolice] = useState('');
  const [civil, setCivil] = useState('');
  const [editingNumberId, setEditingNumberId] = useState<string | undefined>();
  const [formError, setFormError] = useState('');

  const alertBars = useMemo(
    () =>
      Array.from({ length: 7 }, (_, index) => {
        const day = new Date();
        day.setDate(day.getDate() - (6 - index));
        return {
          label: day.toLocaleDateString('fr-FR', { weekday: 'narrow' }),
          count: data.alerts.filter(
            (alert) => new Date(alert.createdAt).toDateString() === day.toDateString(),
          ).length,
        };
      }),
    [data.alerts],
  );

  if (!data.profile || data.role !== 'admin') return <Redirect href="/" />;

  const now = Date.now();
  const filteredAlerts = data.alerts.filter((alert) => {
    const ageDays = (now - new Date(alert.createdAt).getTime()) / 86400000;
    const periodMatches =
      alertPeriod === 'all' ||
      (alertPeriod === 'week' && ageDays <= 7) ||
      (alertPeriod === 'month' && ageDays <= 30);
    return (
      periodMatches &&
      (alertFilter === 'all' || alert.vehicleType === alertFilter) &&
      (alertWilaya === 'all' || alert.wilaya === alertWilaya) &&
      (alertStage === 'all' ||
        alert.stage === alertStage ||
        alert.serviceStatus?.police === alertStage ||
        alert.serviceStatus?.civilProtection === alertStage)
    );
  });
  const filteredUsers = data.knownUsers.filter((user) =>
    `${user.fullName} ${user.username}`.toLowerCase().includes(userQuery.toLowerCase()),
  );
  const nowDate = new Date();
  const alertsToday = data.alerts.filter(
    (alert) => new Date(alert.createdAt).toDateString() === nowDate.toDateString(),
  ).length;
  const alertsWeek = data.alerts.filter(
    (alert) => now - new Date(alert.createdAt).getTime() <= 7 * 86400000,
  ).length;
  const alertsMonth = data.alerts.filter(
    (alert) => now - new Date(alert.createdAt).getTime() <= 30 * 86400000,
  ).length;
  const usersWeek = data.knownUsers.filter(
    (user) => user.createdAt && now - new Date(user.createdAt).getTime() <= 7 * 86400000,
  ).length;
  const usersMonth = data.knownUsers.filter(
    (user) => user.createdAt && now - new Date(user.createdAt).getTime() <= 30 * 86400000,
  ).length;
  const wilayaCounts = Object.entries(
    data.alerts.reduce<Record<string, number>>((counts, alert) => {
      counts[alert.wilaya] = (counts[alert.wilaya] ?? 0) + 1;
      return counts;
    }, {}),
  ).sort((first, second) => second[1] - first[1]);
  const averageArrivalMinutes = (service: ResponseService, alerts: AlertRecord[] = data.alerts) => {
    const responseTimes = alerts.flatMap((alert) => {
      const stage = alert.serviceStatus?.[service] ?? alert.stage;
      const arrivedAt =
        alert.serviceStatusTimestamps?.[service]?.['Test arrived'] ??
        (stage === 'Test arrived' ? alert.responseTimestamps['Test arrived'] : undefined);
      return stage === 'Test arrived' && arrivedAt
        ? [Math.max(0, new Date(arrivedAt).getTime() - new Date(alert.createdAt).getTime())]
        : [];
    });
    return responseTimes.length
      ? responseTimes.reduce((sum, value) => sum + value, 0) / responseTimes.length / 60000
      : null;
  };
  const wilayaResponseRows = Array.from(new Set(data.alerts.map((alert) => alert.wilaya))).map(
    (wilaya) => {
      const alerts = data.alerts.filter((alert) => alert.wilaya === wilaya);
      return {
        wilaya,
        police: averageArrivalMinutes('police', alerts),
        civilProtection: averageArrivalMinutes('civilProtection', alerts),
      };
    },
  );
  const maxCount = Math.max(1, ...alertBars.map((bar) => bar.count));
  const carCount = data.alerts.filter((alert) => alert.vehicleType === 'car').length;
  const motorcycleCount = data.alerts.length - carCount;

  const saveNumbers = () => {
    if (police.trim().length < 3 || civil.trim().length < 3) {
      setFormError('Saisissez deux numéros de démonstration valides.');
      return;
    }
    upsertWilayaNumbers(
      { wilaya: numberWilaya, police: police.trim(), civilProtection: civil.trim() },
      editingNumberId,
    );
    setPolice('');
    setCivil('');
    setEditingNumberId(undefined);
    setFormError('');
  };

  const editNumbers = (entry: (typeof data.wilayaNumbers)[number]) => {
    setNumberWilaya(entry.wilaya);
    setPolice(entry.police);
    setCivil(entry.civilProtection);
    setEditingNumberId(entry.id);
    setFormError('');
  };

  return (
    <Page>
      <View style={styles.header}>
        <View style={{ flex: 1, gap: 5 }}>
          <AppText style={{ color: colors.mutedForeground, fontSize: 12, fontWeight: '700', letterSpacing: 1.2 }}>SOLVEX / ADMIN</AppText>
          <Heading>{t(data.language, 'admin')}</Heading>
          <AppText style={{ color: colors.mutedForeground, fontSize: 13 }}>{t(data.language, 'testData')}</AppText>
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel={t(data.language, 'signOut')} onPress={signOut} style={[styles.exitIcon, { backgroundColor: colors.card, borderColor: colors.border }]}>
          <Feather name="log-out" size={17} color={colors.deepNavy} />
        </Pressable>
      </View>
      <DemoBanner />

      <View style={{ gap: 12 }}>
        <SectionTitle>{t(data.language, 'adminSummary')}</SectionTitle>
        <View style={styles.statsGrid}>
          <Stat label={t(data.language, 'users')} value={data.knownUsers.length} icon="users" />
          <Stat label={t(data.language, 'alerts')} value={data.alerts.length} icon="alert-triangle" tone="danger" />
          <Stat label={`${t(data.language, 'devices')} · voiture`} value={data.deviceConnected && data.vehicleType === 'car' ? 1 : 0} icon="truck" />
          <Stat label={`${t(data.language, 'devices')} · moto`} value={data.deviceConnected && data.vehicleType === 'motorcycle' ? 1 : 0} icon="navigation" />
        </View>
        <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
          Nouveaux profils locaux · 7 j : {usersWeek} · 30 j : {usersMonth}
        </AppText>
      </View>

      <Card>
        <View style={styles.rowBetween}>
          <View style={{ flex: 1, gap: 4 }}>
            <AppText style={{ fontSize: 16, fontWeight: '700', color: colors.deepNavy }}>Alertes · 7 jours</AppText>
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>Historique de test local uniquement</AppText>
          </View>
          <Badge>{data.alerts.length} total</Badge>
        </View>
        <View style={styles.rowBetween}>
          <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>Aujourd’hui · {alertsToday}</AppText>
          <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>7 j · {alertsWeek}</AppText>
          <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>30 j · {alertsMonth}</AppText>
        </View>
        <View style={styles.chart}>
          {alertBars.map((item, index) => (
            <View key={`${item.label}-${index}`} style={styles.chartColumn}>
              <AppText style={{ fontSize: 10, color: colors.mutedForeground }}>{item.count || ''}</AppText>
              <View style={[styles.barTrack, { backgroundColor: colors.secondary }]}>
                <View style={[styles.bar, { height: `${Math.max(7, (item.count / maxCount) * 100)}%`, backgroundColor: item.count ? colors.primary : colors.mapRoad }]} />
              </View>
              <AppText style={{ fontSize: 10, color: colors.mutedForeground }}>{item.label}</AppText>
            </View>
          ))}
        </View>
        <View style={styles.rowBetween}>
          <View style={styles.vehicleCount}>
            <View style={[styles.dot, { backgroundColor: colors.primary }]} />
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>Voiture · {carCount}</AppText>
          </View>
          <View style={styles.vehicleCount}>
            <View style={[styles.dot, { backgroundColor: colors.signal }]} />
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>Moto · {motorcycleCount}</AppText>
          </View>
        </View>
        <View style={[styles.breakdown, { backgroundColor: colors.secondary }]}>
          <View style={styles.rowBetween}>
            <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 12 }}>Répartition par wilaya</AppText>
            <Feather name="map-pin" size={15} color={colors.primary} />
          </View>
          {wilayaCounts.length ? (
            wilayaCounts.slice(0, 4).map(([wilaya, count]) => (
              <View key={wilaya} style={styles.rowBetween}>
                <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>{wilaya}</AppText>
                <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 11 }}>{count}</AppText>
              </View>
            ))
          ) : (
            <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>Pas encore d’événement local.</AppText>
          )}
        </View>
        <View style={[styles.responseSummary, { borderColor: colors.border }]}>
          <View style={{ flex: 1, gap: 5 }}>
            <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 13 }}>{t(data.language, 'response')}</AppText>
            <View style={styles.rowBetween}>
              <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>Police · test</AppText>
              <AppText style={{ color: colors.deepNavy, fontSize: 11, fontWeight: '700' }}>
                {averageArrivalMinutes('police') === null ? '—' : `${averageArrivalMinutes('police')!.toFixed(1)} min`}
              </AppText>
            </View>
            <View style={styles.rowBetween}>
              <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>Protection civile · test</AppText>
              <AppText style={{ color: colors.deepNavy, fontSize: 11, fontWeight: '700' }}>
                {averageArrivalMinutes('civilProtection') === null ? '—' : `${averageArrivalMinutes('civilProtection')!.toFixed(1)} min`}
              </AppText>
            </View>
          </View>
        </View>
        {wilayaResponseRows.length ? (
          <View style={[styles.breakdown, { backgroundColor: colors.secondary }]}>
            <AppText style={{ color: colors.deepNavy, fontWeight: '700', fontSize: 12 }}>Délai simulé par wilaya</AppText>
            {wilayaResponseRows.slice(0, 4).map((row) => (
              <View key={row.wilaya} style={styles.rowBetween}>
                <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>{row.wilaya}</AppText>
                <AppText style={{ color: colors.deepNavy, fontSize: 10 }}>
                  P {row.police === null ? '—' : `${row.police.toFixed(1)}m`} · PC {row.civilProtection === null ? '—' : `${row.civilProtection.toFixed(1)}m`}
                </AppText>
              </View>
            ))}
          </View>
        ) : null}
        <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
          Aucune statistique n’est synchronisée entre appareils ou vers Firebase.
        </AppText>
        <ActionButton
          label="Carte des incidents"
          icon="map"
          variant="secondary"
          onPress={() => router.push('/(tabs)/map')}
        />
      </Card>

      <Card>
        <SectionTitle>{t(data.language, 'alerts')}</SectionTitle>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterScroll}>
          <View style={styles.row}>
            {(['all', 'week', 'month'] as const).map((period) => {
              const active = alertPeriod === period;
              const label = period === 'all' ? t(data.language, 'all') : period === 'week' ? t(data.language, 'thisWeek') : t(data.language, 'thisMonth');
              return (
                <FilterChip key={period} label={label} active={active} onPress={() => setAlertPeriod(period)} />
              );
            })}
          </View>
        </ScrollView>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterScroll}>
          <View style={styles.row}>
            {(['all', 'car', 'motorcycle'] as const).map((filter) => {
              const active = alertFilter === filter;
              const label = filter === 'all' ? t(data.language, 'all') : filter === 'car' ? t(data.language, 'car') : t(data.language, 'motorcycle');
              return (
                <FilterChip key={filter} label={label} active={active} onPress={() => setAlertFilter(filter)} />
              );
            })}
          </View>
        </ScrollView>
        <View style={styles.row}>
          <Pressable
            accessibilityRole="button"
            onPress={() => setAlertWilaya('all')}
            style={[styles.filter, { backgroundColor: alertWilaya === 'all' ? colors.deepNavy : colors.card, borderColor: alertWilaya === 'all' ? colors.deepNavy : colors.border }]}
          >
            <AppText style={{ fontSize: 11, fontWeight: '700', color: alertWilaya === 'all' ? colors.primaryForeground : colors.mutedForeground }}>Toutes les wilayas</AppText>
          </Pressable>
          <View style={{ flex: 1 }}>
            <WilayaPicker value={alertWilaya === 'all' ? data.wilaya : alertWilaya} onSelect={setAlertWilaya} />
          </View>
        </View>
        <View style={styles.stageFilters}>
          {(['all', ...stages] as const).map((stage) => {
            const active = alertStage === stage;
            return (
              <Pressable
                key={stage}
                accessibilityRole="button"
                onPress={() => setAlertStage(stage)}
                style={[styles.filter, { backgroundColor: active ? colors.deepNavy : colors.card, borderColor: active ? colors.deepNavy : colors.border }]}
              >
                <AppText style={{ fontSize: 10, fontWeight: '700', color: active ? colors.primaryForeground : colors.mutedForeground }}>
                  {stage === 'all' ? t(data.language, 'all') : stage.replace('Test ', '')}
                </AppText>
              </Pressable>
            );
          })}
        </View>
        {filteredAlerts.length === 0 ? (
          <AppText style={{ color: colors.mutedForeground, fontSize: 13, paddingVertical: 8 }}>
            Aucune alerte locale ne correspond au filtre.
          </AppText>
        ) : (
          filteredAlerts.map((alert) => {
            const date = new Date(alert.createdAt);
            return (
              <View key={alert.id} style={[styles.alertAdmin, { borderTopColor: colors.border }]}>
                <View style={[styles.alertAdminIcon, { backgroundColor: colors.dangerSurface }]}>
                  <Feather name="alert-triangle" size={16} color={colors.signal} />
                </View>
                <View style={{ flex: 1, gap: 4 }}>
                  <AppText style={{ fontWeight: '700', fontSize: 13, color: colors.deepNavy }}>{alert.wilaya} · {alert.vehicleType === 'car' ? 'Voiture' : 'Moto'}</AppText>
                  <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
                    {date.toLocaleDateString('fr-FR')} · {date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                  </AppText>
                  {alert.latitude !== null ? (
                    <AppText style={{ color: colors.mutedForeground, fontSize: 10 }}>{alert.latitude.toFixed(4)}, {alert.longitude?.toFixed(4)}</AppText>
                  ) : null}
                </View>
                <View style={{ gap: 7 }}>
                  <ServiceStatusControl
                    service="police"
                    label="Police"
                    status={alert.serviceStatus?.police ?? alert.stage}
                    onAdvance={(stage) => updateAlertStage(alert.id, 'police', stage)}
                  />
                  <ServiceStatusControl
                    service="civilProtection"
                    label="PC"
                    status={alert.serviceStatus?.civilProtection ?? alert.stage}
                    onAdvance={(stage) => updateAlertStage(alert.id, 'civilProtection', stage)}
                  />
                  <ActionButton
                    label="Carte & détails"
                    icon="map-pin"
                    variant="outline"
                    onPress={() => router.push({ pathname: '/alert-details', params: { id: alert.id } })}
                    style={{ minHeight: 34, paddingHorizontal: 8 }}
                  />
                </View>
              </View>
            );
          })
        )}
        <AppText style={{ color: colors.mutedForeground, fontSize: 11, lineHeight: 16 }}>
          Les statuts ci-dessus sont modifiables pour la démonstration; aucune équipe n’est contactée.
        </AppText>
      </Card>

      <Card style={{ gap: 13 }}>
        <SectionTitle>{t(data.language, 'users')}</SectionTitle>
        <Input label={t(data.language, 'search')} value={userQuery} onChangeText={setUserQuery} placeholder="Nom ou identifiant" />
        {filteredUsers.length === 0 ? (
          <AppText style={{ color: colors.mutedForeground, fontSize: 13 }}>Aucun profil local.</AppText>
        ) : (
          filteredUsers.map((user) => {
            const disabled = data.disabledUsers.includes(user.username.toLowerCase());
            return (
              <View key={user.username} style={styles.rowBetween}>
                <View style={{ flex: 1, gap: 3 }}>
                  <AppText style={{ fontWeight: '700', fontSize: 13 }}>{user.fullName}</AppText>
                  <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>@{user.username} · {user.wilaya}</AppText>
                </View>
                <ActionButton
                  label={disabled ? 'Réactiver' : 'Désactiver'}
                  icon={disabled ? 'user-check' : 'user-x'}
                  variant={disabled ? 'secondary' : 'outline'}
                  onPress={() => toggleUserDisabled(user.username)}
                  style={{ minHeight: 38, paddingHorizontal: 11 }}
                />
              </View>
            );
          })
        )}
        <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>
          La gestion porte uniquement sur les profils de démonstration de cet appareil.
        </AppText>
      </Card>

      <Card>
        <SectionTitle>{t(data.language, 'numbers')}</SectionTitle>
        <AppText style={{ color: colors.mutedForeground, fontSize: 12, lineHeight: 17 }}>
          Ces numéros sont des données locales de démo. Aucun numéro n’est appelé ou utilisé pour les alertes.
        </AppText>
        <WilayaPicker label={t(data.language, 'wilaya')} value={numberWilaya} onSelect={setNumberWilaya} />
        <Input label={t(data.language, 'police')} value={police} onChangeText={setPolice} keyboardType="phone-pad" placeholder="Numéro de test" />
        <Input label={t(data.language, 'civilProtection')} value={civil} onChangeText={setCivil} keyboardType="phone-pad" placeholder="Numéro de test" />
        {formError ? <AppText style={{ color: colors.signal, fontSize: 12 }}>{formError}</AppText> : null}
        <View style={styles.row}>
          {editingNumberId ? (
            <ActionButton
              label={t(data.language, 'cancel')}
              variant="outline"
              onPress={() => {
                setEditingNumberId(undefined);
                setPolice('');
                setCivil('');
                setFormError('');
              }}
              style={{ flex: 1 }}
            />
          ) : null}
          <ActionButton
            label={editingNumberId ? t(data.language, 'save') : 'Ajouter'}
            icon="save"
            onPress={saveNumbers}
            testID="save-wilaya-numbers"
            style={{ flex: 1 }}
          />
        </View>
        <View style={{ gap: 9, paddingTop: 4 }}>
          {data.wilayaNumbers.map((entry) => (
            <View key={entry.id} style={[styles.numberRow, { borderColor: colors.border, backgroundColor: colors.card }]}>
              <View style={{ flex: 1, gap: 3 }}>
                <AppText style={{ fontWeight: '700', fontSize: 13 }}>{entry.wilaya}</AppText>
                <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>P {entry.police} · PC {entry.civilProtection}</AppText>
              </View>
              <Pressable accessibilityRole="button" accessibilityLabel="Modifier les numéros" onPress={() => editNumbers(entry)} style={styles.iconAction}>
                <Feather name="edit-2" size={15} color={colors.primary} />
              </Pressable>
              <Pressable accessibilityRole="button" accessibilityLabel="Supprimer les numéros" onPress={() => deleteWilayaNumbers(entry.id)} style={styles.iconAction}>
                <Feather name="trash-2" size={15} color={colors.signal} />
              </Pressable>
            </View>
          ))}
          {data.wilayaNumbers.length === 0 ? (
            <AppText style={{ color: colors.mutedForeground, fontSize: 12 }}>Aucun numéro de démo configuré.</AppText>
          ) : null}
        </View>
      </Card>
      <ActionButton label={t(data.language, 'signOut')} icon="log-out" variant="outline" onPress={signOut} />
    </Page>
  );
}

function Stat({
  label,
  value,
  icon,
  tone = 'primary',
}: {
  label: string;
  value: number;
  icon: keyof typeof Feather.glyphMap;
  tone?: 'primary' | 'danger';
}) {
  const colors = useColors();
  return (
    <Card style={{ flex: 1, minWidth: '46%', padding: 14, gap: 10 }}>
      <View style={[styles.statIcon, { backgroundColor: tone === 'danger' ? colors.dangerSurface : colors.accent }]}>
        <Feather name={icon} size={16} color={tone === 'danger' ? colors.signal : colors.primary} />
      </View>
      <AppText style={{ color: colors.deepNavy, fontSize: 22, fontWeight: '800' }}>{value}</AppText>
      <AppText style={{ color: colors.mutedForeground, fontSize: 11 }}>{label}</AppText>
    </Card>
  );
}

function FilterChip({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  const colors = useColors();
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={[
        styles.filter,
        {
          backgroundColor: active ? colors.deepNavy : colors.card,
          borderColor: active ? colors.deepNavy : colors.border,
        },
      ]}
    >
      <AppText style={{ fontSize: 11, fontWeight: '700', color: active ? colors.primaryForeground : colors.mutedForeground }}>
        {label}
      </AppText>
    </Pressable>
  );
}

function ServiceStatusControl({
  service,
  label,
  status,
  onAdvance,
}: {
  service: ResponseService;
  label: string;
  status: AlertStage;
  onAdvance: (stage: AlertStage) => void;
}) {
  const colors = useColors();
  const current = stages.indexOf(status);
  const next = stages[Math.min(current + 1, stages.length - 1)] ?? status;
  return (
    <View style={styles.serviceControl}>
      <AppText style={{ color: colors.mutedForeground, fontSize: 10 }}>{label}</AppText>
      <Badge tone="warning">{status.replace('Test ', '')}</Badge>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Avancer le statut ${label}`}
        disabled={current >= stages.length - 1}
        onPress={() => onAdvance(next)}
        style={[
          styles.advance,
          { borderColor: colors.border, opacity: current >= stages.length - 1 ? 0.4 : 1 },
        ]}
      >
        <AppText style={{ fontSize: 10, color: colors.primary, fontWeight: '700' }}>+ étape</AppText>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  row: { flexDirection: 'row', gap: 8 },
  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  exitIcon: { width: 42, height: 42, borderWidth: 1, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  statIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  chart: { height: 150, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-around', gap: 8 },
  chartColumn: { height: '100%', alignItems: 'center', justifyContent: 'flex-end', gap: 7, flex: 1 },
  barTrack: { width: 19, flex: 1, justifyContent: 'flex-end', borderRadius: 9, overflow: 'hidden' },
  bar: { width: '100%', borderRadius: 9, minHeight: 6 },
  vehicleCount: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  dot: { width: 8, height: 8, borderRadius: 4 },
  filter: { borderWidth: 1, borderRadius: 99, paddingHorizontal: 12, paddingVertical: 8 },
  filterScroll: { gap: 7 },
  stageFilters: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  breakdown: { borderRadius: 13, padding: 11, gap: 8 },
  responseSummary: { borderWidth: 1, borderRadius: 14, padding: 11, flexDirection: 'row', alignItems: 'center', gap: 9 },
  serviceControl: { alignItems: 'flex-end', gap: 4 },
  alertAdmin: { borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 13, flexDirection: 'row', alignItems: 'center', gap: 9 },
  alertAdminIcon: { width: 34, height: 34, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  advance: { borderWidth: 1, borderRadius: 9, paddingHorizontal: 8, paddingVertical: 5 },
  numberRow: { borderWidth: 1, borderRadius: 13, padding: 10, flexDirection: 'row', alignItems: 'center', gap: 6 },
  iconAction: { width: 30, height: 30, alignItems: 'center', justifyContent: 'center' },
});
