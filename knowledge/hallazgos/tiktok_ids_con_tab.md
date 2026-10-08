# Hallazgo: Order ID / SKU ID de TikTok traen tabs ocultos

**Dominio:** tiktok · **Estado:** resuelto en Power BI · **Última verificación:** 2026-10 (PBI TT V8)

## Síntoma
La relación por Primary ID (Order ID + SKU ID) no emparejaba el volumen esperado de filas.

## Causa
Los CSV crudos traen caracteres tab (`\t`) invisibles en Order ID y SKU ID. Power Query concatenaba
antes de la conversión de tipo que los limpiaba, así que las llaves no coincidían.

## Solución
- Power BI: `Text.Remove` sobre Order ID y SKU ID **antes** de concatenar
  (tablas *All Orders - Complete* y *All Orders - Affiliate Samples*).
- En SQL, el equivalente:
  ```sql
  TRIM(REPLACE(order_id, E'\t', '')) || '|' || TRIM(REPLACE(sku_id, E'\t', '')) AS primary_id
  ```

## Lo que NO funcionó
- Deduplicar por Order ID solo → se pierden líneas de órdenes multi-SKU.

## Pendiente relacionado
- La columna calculada *Type* aún empareja por Order ID (no Primary ID): ~300 casos mal resueltos.
