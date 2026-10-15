import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  checkRow,
  discoveryDocument,
  publicUrl,
  publishableKey,
} from "./server_info.ts";

const env = (vars: Record<string, string>) => (name: string) => vars[name];

const row = {
  api_version: 1,
  min_app_version: "1.0.0",
  household_creation: "token",
  features: ["calendar", "shopping"],
};

Deno.test("publicUrl prefers the operator's address", () => {
  assertEquals(
    publicUrl(env({
      WW_PUBLIC_URL: "https://family.example.org/",
      SUPABASE_PUBLIC_URL: "https://api.example.org",
    })),
    "https://family.example.org",
  );
});

Deno.test("publicUrl never hands out the compose stack's internal gateway", () => {
  assertEquals(
    publicUrl(env({ SUPABASE_URL: "http://api-gw:8000" })),
    undefined,
  );
  assertEquals(
    publicUrl(env({
      SUPABASE_URL: "http://api-gw:8000",
      SUPABASE_PUBLIC_URL: "https://api.example.org",
    })),
    "https://api.example.org",
  );
});

Deno.test("publicUrl takes hosted Supabase's public SUPABASE_URL", () => {
  assertEquals(
    publicUrl(env({ SUPABASE_URL: "https://abcd.supabase.co" })),
    "https://abcd.supabase.co",
  );
});

Deno.test("publicUrl refuses a path or plain http", () => {
  assertEquals(publicUrl(env({ WW_PUBLIC_URL: "http://example.org" })), undefined);
  assertEquals(
    publicUrl(env({ WW_PUBLIC_URL: "https://example.org/supabase" })),
    undefined,
  );
});

Deno.test("publishableKey reads the default publishable key", () => {
  assertEquals(
    publishableKey(env({
      SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_publishable_abc"}',
      SUPABASE_ANON_KEY: "eyJ.legacy",
    })),
    "sb_publishable_abc",
  );
});

Deno.test("publishableKey never returns a secret key", () => {
  assertEquals(
    publishableKey(env({ SUPABASE_PUBLISHABLE_KEYS: '{"default":"sb_secret_x"}' })),
    undefined,
  );
});

Deno.test("publishableKey falls back to the legacy anon key", () => {
  assertEquals(
    publishableKey(env({ SUPABASE_PUBLISHABLE_KEYS: '{"default":""}', SUPABASE_ANON_KEY: "eyJ.anon" })),
    "eyJ.anon",
  );
  assertEquals(publishableKey(env({})), undefined);
});

Deno.test("checkRow refuses a half-migrated answer", () => {
  assertThrows(() => checkRow(null));
  assertThrows(() => checkRow({ ...row, api_version: "1" }));
  assertThrows(() => checkRow({ ...row, features: [1] }));
  assertEquals(checkRow(row), row);
});

Deno.test("discoveryDocument reports redirect sign-in as Auth has it", () => {
  const doc = discoveryDocument(
    row,
    { external: { apple: true, google: false, email: true } },
    "sb_publishable_abc",
    "https://api.example.org",
  );
  assertEquals(doc, {
    wuselwall: 1,
    supabase_url: "https://api.example.org",
    publishable_key: "sb_publishable_abc",
    api_version: 1,
    min_app_version: "1.0.0",
    household_creation: "token",
    sign_in: { password: true, apple: true, google: false },
    features: ["calendar", "shopping"],
  });
});

Deno.test("discoveryDocument leaves the address out when it is unknown", () => {
  const doc = discoveryDocument(row, {}, "k", undefined);
  assertEquals("supabase_url" in doc, false);
  assertEquals(doc.sign_in, { password: true, apple: false, google: false });
});
