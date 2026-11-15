// The providers a server knows, and the catalogue the apps list (specs/30 "Services"). A new
// provider is one file in ./providers/ and one line here.
import { capabilitiesOf, type Capability, type Cost, type Provider, type Receives } from "./types.ts";
import { openMeteo } from "./providers/open-meteo.ts";
import { metNo } from "./providers/met-no.ts";
import { nominatim } from "./providers/nominatim.ts";
import { openWeatherMap } from "./providers/openweathermap.ts";
import { meteostat } from "./providers/meteostat.ts";
import { openRouteService } from "./providers/openrouteservice.ts";
import { google } from "./providers/google.ts";

/** Every provider, in the order the settings page lists them. */
export const PROVIDERS: readonly Provider[] = [
  openMeteo,
  metNo,
  nominatim,
  openWeatherMap,
  meteostat,
  openRouteService,
  google,
];

export function findProvider(id: string, registry: readonly Provider[] = PROVIDERS): Provider | undefined {
  return registry.find((p) => p.id === id);
}

/** One entry of the `catalogue` answer. */
export type CatalogueEntry = {
  id: string;
  name: string;
  homepage: string;
  key_url: string | null;
  needs_key: boolean;
  cost: Cost;
  capabilities: Capability[];
  receives: Receives[];
  attribution: string;
};

export function catalogue(registry: readonly Provider[] = PROVIDERS): { providers: CatalogueEntry[] } {
  return {
    providers: registry.map((p) => ({
      id: p.id,
      name: p.name,
      homepage: p.homepage,
      key_url: p.key_url,
      needs_key: p.needs_key,
      cost: p.cost,
      capabilities: capabilitiesOf(p),
      receives: [...p.receives],
      attribution: p.attribution,
    })),
  };
}
