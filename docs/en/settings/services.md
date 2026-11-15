# Weather and maps

For the [Trips](/en/trips/), WuselWall can ask services run by other companies: how warm a place typically is, what the weather will be in the next few days, where a place is and how long the drive takes. This is **entirely optional**. Everything else about trips works without these services, and without them your server asks nobody.

The services can add:

- **Typical climate**: how warm, rainy and sunny a place usually is in a month, and by the sea the water temperature. [Where to?](/en/trips/#discover) shows it
- **Forecast**: the weather at the destination in the days before and during the trip
- **Place search**: finding a destination or your home place by name
- **Driving time**: how long the drive from home takes by car
- **Map picture**: a small picture of the destination on the trip's page

You switch it on under **Settings → Calendar & school → Sharing and connections → Weather and maps**. Only parents can do that. Other adults see the page and the note **A parent can change this**.

<Shot name="settings-services" alt="The Weather and maps page with the home place and the provider Open-Meteo, switched on, with a Test button" />

## Three promises {#promises}

1. **Everything is off until a parent switches it on.** A new server asks no weather and no map service. If you switch a provider off again, every call to it stops at once.
2. **Only your family's server asks the provider**, never a phone and never the wall. Your phone only talks to your server. The server fetches a map picture and passes it on.
3. **A provider learns only what the question needs:**
   - the place you look at or search for: its coordinates or the text of the search
   - for a driving time also your home place, rounded to about a kilometre
   - and, unavoidably, the internet address of your server

   **Nothing about your family**: no names, no account, no appointments, no travel dates.

Your server remembers the answers so that the same question is not asked again: typical climate for five years, a place that was found for 90 days, a driving time and a map picture for 30 days, a forecast for 3 hours. This store only holds public facts about places, nothing about your family.

## The providers {#providers}

Each provider is a separate offer with its own terms. The page shows for each what it can do, whether it needs a key and what it receives (**It receives: …**).

| Provider | Key | Can do |
|---|---|---|
| **Open-Meteo** | no, free | Typical climate, forecast, place search |
| **MET Norway** | no, free | Forecast |
| **OpenStreetMap Nominatim** | no, free | Place search |
| **OpenWeather** | yes, your own key, a free plan is possible | Forecast (for about five days), place search |
| **Meteostat** | yes, your own key, a free plan is possible | Typical climate |
| **openrouteservice** | yes, your own key, a free plan is possible | Driving time, place search |
| **Google Maps Platform** | yes, your own key, may cost | Place search, driving time, map picture |

- **Without a key** you can start at once. With **Open-Meteo** you get climate, forecast and place search from one provider.
- **With your own key** you sign up with the provider and enter the key in WuselWall (see [below](#keys)). On the provider's card **Get a key** leads to the right page.
- A **driving time** is only available with **openrouteservice** or **Google Maps Platform**, a **map picture** only with **Google Maps Platform**; both need a key. Only for the driving time does the provider also receive your home place, rounded.
- **The terms are yours to accept.** Some free offers are for private use only; Open-Meteo, for example, according to the provider, is only for non-commercial use. An offer with a key may cost money; WuselWall promises nothing about prices. A small daily ceiling protects your key from a loop, but it is no protection against costs.
- Under every map picture and forecast stands the provider's credit line.

::: warning Honestly
The providers with a key were built from their documentation, not tried with your key. If one does not work with your key, the **Test** button tells you (see [below](#test)).
:::

## Setting the home place {#home}

At the top of the page is **Home**. The place is there for the distances in **Where to?** and for the driving time. Tap **Set**, type the **Name of the place** and tap **Search**; a match sets the place. For that, a provider with **Place search** must be switched on. Without one you type the **Latitude** and **Longitude** by hand, with two decimals.

The place is stored rounded to about a kilometre. **Change** sets a new one; **Forget** makes the distances disappear until a new one is set.

## Adding a key {#keys}

A provider with a key first shows **Needs a key first**. Get the key from the provider, type it into the **Key** field and choose **Save key and switch on**.

- **A key is written, never read.** It is typed once and stored on your server. After that the page only shows its last four characters: **Key stored …1234**. No device can read it out, not even yours.
- It is **not in the family's data export** and in no log. A backup of your server holds it, like the server's other secrets.
- **Replace** swaps it. **Remove** deletes it and switches the provider off.

## Order and testing {#test}

Under **Switched on** there is the **Test** button. It makes one small real call and answers **Works** or names the reason. Try it right after entering a key.

In the **Advanced** view (top right) there is more:

- **Used for**: ticks for what the provider should do for you. A provider can, for example, only supply the forecast.
- **Ask earlier** and **Ask later**: where several providers offer the same thing, **the first one in this order that answers wins**. If it does not answer, the next one is asked.
- How many **calls today** there have been.

## Why the first time takes a while {#slow}

Open-Meteo's free service allows only a few climate lookups: roughly **three places a minute**, twenty an hour and forty-eight a day. Your server keeps to that. So the list in **Where to?** fills slowly the first time: at the top it says "Climate values are being loaded: 12 places to go", and the page asks again every half minute. If nothing new comes for a while it stops and says "More values will follow later".

That is fine. Look again later. Fewer places go faster: with one or two **wishes** (for example **Sea**), fewer places have to be asked. After that it is quick: the values are **averages** and stay stored for five years, for every family on your server.

## When the service does not answer {#no-answer}

If a call did not work, a provider shows the reason under **Last call**:

- **The provider refused the key.** The key is wrong or has expired. With **Replace** you enter a new one.
- **The provider's allowance is used up for now.** Wait until it renews, or add another provider.
- **The provider did not answer in time** and **The provider did not work this time.** This happens. Try again later with **Test**.
- **This provider needs a key.** Enter one first.

If several providers are switched on, the server asks the next one. A trip's page never shows an error: what a service does not supply is simply missing, and everything else carries on.
