# LICENCIAS.md - comparacion Headscale contra NetBird y justificacion de la eleccion

Este documento es deliberado: fija la eleccion técnica del kit de acceso remoto
y deja por escrito por que se descarto la alternativa. Es el documento que hay
que mostrar cuando alguien pregunte "y por que no NetBird?".

Fecha de verificación: **17 de octubre de 2026**.
Todo lo afirmado aquí se leyo de los archivos de los tags exactos citados.

---

## 1. Respuesta corta

**Ninguna de las dos opciones tiene una licencia que impida la reventa.** Las dos
se pueden usar y vender comercialmente. Por lo tanto, **el kit se construye**, y
la eleccion se define por operación, no por bloqueo legal.

**Elegido: Headscale v0.29.5**, licencia BSD 3-Clause.
**Descartado: NetBird v0.81.2**, licencia BSD 3-Clause con una parte importante
en AGPLv3.

---

## 2. Verificación de licencias

### 2.1 Headscale v0.29.5 - BSD 3-Clause, sin excepciones

El archivo LICENSE del tag v0.29.5 es BSD 3-Clause a texto completo, con
copyright de Juan Font, sin ninguna carve-out para subdirectorios.

Fuente: <https://github.com/juanfont/headscale/blob/v0.29.5/LICENSE>

> Copyright (c) 2020, Juan Font. All rights reserved.

Es una licencia permisiva. Permite uso comercial, redistribucion, modificacion y
reventa. Las tres condiciones son de atribucion: conservar el aviso de copyright,
conservar el texto de la licencia, y no usar el nombre de los autores para
respaldar sin permiso. Ninguna de las tres condiciones impide cobrar por un
servicio gestionado.

### 2.2 NetBird v0.81.2 - BSD 3-Clause con carve-out a AGPLv3

Este es el hallazgo relevante. El archivo LICENSE del tag v0.81.2 dice textualmente:

> This BSD-3-Clause license applies to all parts of the repository except for
> the directories management/, signal/, relay/ and combined/.
> Those directories are licensed under the GNU Affero General Public License
> versión 3.0 (AGPLv3). See the respective LICENSE files inside each directory.

Fuente: <https://github.com/netbirdio/netbird/blob/v0.81.2/LICENSE>

Y el cuerpo del texto es BSD 3-Clause, copyright de NetBird GmbH y autores.

**Que significa esto en la práctica para Hefesto:** los directorios con carve-out
son precisamente los componentes de servidor que corre el servicio autoalojado:
`management`, `signal`, `relay` y `combined`. Es decir, la parte central de la
plataforma, no un detalle periférico.

AGPLv3 **no prohibe la reventa ni el uso comercial**. Exige otra cosa: si se
modifica un componente y se ofrece por red a usuarios, hay que ofrecerles el
código fuente correspondiente completo. Para un servicio recurrente que se
entrega a clientes finales, eso significa:

1. Trackear si Hefesto modifica alguno de esos componentes. Si no los modifica,
   la obligación se reduce mucho.
2. Tener resuelto, por escrito, qué se ofrece y a quién, en caso de que un
   cliente o su auditor pregunte.

Nada de esto es imposible, pero es una tarea legal y operativa que no existe con
Headscale. Para una agencia que quiere vender esto como producto recurrente y
rápido, es una carga que no compra nada.

**Conclusion de licencias:** ninguna de las dos es incompatible con la reventa.
Headscale es materialmente mas limpia. No es una razon suficiente por si sola,
pero pesa.

---

## 3. Comparacion operativa

Datos leidos del compose oficial de NetBird en el tag v0.81.2:
<https://github.com/netbirdio/netbird/blob/v0.81.2/infrastructure_files/docker-compose.yml.tmpl>

| Criterio | Headscale v0.29.5 | NetBird v0.81.2 |
|---|---|---|
| Licencia | BSD 3-Clause, sin excepciones | BSD 3-Clause + **AGPLv3 en `management/`, `signal/`, `relay/`, `combined/`** |
| Contenedores obligatorios en su despliegue autoalojado | **1** (headscale) | **5**: dashboard, signal, relay, management, coturn |
| Base de datos | SQLite (por defecto y recomendado) | PostgreSQL **o** MySQL, externa al compose; sin SQLite para el servidor de gestión |
| Consola web | **No tiene** | Si, panel de administración |
| Cliente en los nodos | Aplicaciones oficiales de Tailscale | Cliente propio de NetBird |
| Puertos públicos del servidor de coordinacion | HTTPS 443, y nada mas en la configuración de este kit | Dashboard 80 y 443, mas puerto de signal, mas relay, y coturn en red del host |
| Doble cifrado de extremo a extremo | No | Si, mediante Signal |
| Control de acceso | Política huJSON (grants, ssh, etiquetas) | Políticas y ACL con interfaz grafica |
| Integración con CrowdSec | No aplica | Si, con modo `enforce` y `observe` |
| Revocacion de dispositivos | CLI | Consola web |
| Componentes que hay que operar y vigilar | 1 | 5 mas la base de datos |

### 3.1 Cuantos componentes son realmente obligatorios en NetBird

Este punto merecia verificación porque es la diferencia entre vender "un
contenedor" o vender "cinco". Leyendo el compose oficial del tag v0.81.2, los
cinco servicios estan declarados y commented out del bloque obligatorio:

- `dashboard`: interfaz web de administración.
- `signal`: descubrimiento de pares y coordinacion de conexiones.
- `relay`: transmision para pares que no logran conexión directa.
- `management`: servidor de gestión, el nucleo, y el que apunta a la base de datos.
- `coturn`: servidor STUN y TURN, en modo de red del host.

Ademas, el compose **no incluye** la base de datos: la variable
`NETBIRD_STORE_ENGINE_POSTGRES_DSN` apunta a una instancia externa, que el
guia de arranque oficial provisiona por separado. Con base de datos, el
conjunto real es de seis piezas.

### 3.2 Que usuarios de red obligatorios tiene cada uno

En la configuración que propone este kit, Headscale **no necesita ningun puerto
UDP en el servidor de coordinacion**. El DERP embebido viene apagado por defecto
y este kit lo mantiene apagado. Fuentes: `docs/setup/requirements.md` y
`config-example.yaml` del tag v0.29.5, donde upstream etiqueta el puerto
udp/3478 como "solo si se usa el DERP embebido".

NetBird, en cambio, pública el dashboard en 80 y 443, expone un puerto propio de
signal, un puerto de relay, y ademas el contenedor de coturn corre en modo de red
del host, lo que hace que sus puertos UDP y TCP de NAT traversal se apliquen sin
filtrar.

Para una propuesta comercial cuya promesa central es "no abrimos sus servidores
a internet", pagar esa superficie en el servidor de coordinacion no tiene buen
negocio.

---

## 4. Criterio de la decisión

Se evaluaron cuatro criterios, en este orden:

**Primero, cumplimiento de licencias.** No era bloqueante en ninguno de los dos,
pero Headscale evita por completo la gestión de obligaciones AGPL sobre los
componentes de servidor. Ventaja real para un servicio recurrente.

**Segundo, costo operativo de lo vendido.** Un contenedor y una base SQLite
contra cinco contenedores y una base de datos externa. El kit se factura como
servicio recurrente: cada cliente es un despliegue mas que hay que upholdar,
respaldar y auditar. Menos piezas significa menos respaldos, menos superficies y
menos noches de guardia.

**Tercero, superficie de red.** Un solo puerto público (HTTPS 443) contra una
docena. Esta es la promesa comercial del producto, y hay que poder cumplirla
literalmente. Headscale lo cumple en la configuración entregada; NetBird exige
aceptar que el servidor de coordinacion sea un servidor con muchos puertos.

**Cuarto, experiencia del cliente final.** Los nodos usan aplicaciones oficiales
de Tailscale que el cliente final probablemente ya conoce. Un cliente propio
seria una app distinta que hay que distribuir, documentar y soportar.

### 4.1 La objecion que se evaluo con mas cuidado

Se recibio el reparo de que **Headscale tiene incompatibilidades con las versiones
nuevas de Tailscale**, porque depende de mantener la compatibilidad con un cliente
que evoluciona rapido. **El riesgo es real y no se minimiza.**

Lo que se verifico, en `docs/about/clients.md` del tag v0.29.5:

> We aim to support the **last 10 releases** of the Tailscale client on all
> provided operating systems and platforms.

La política de compatibilidad de upstream es explicita y con ventana de soporte.
La incompatibilidad no vendria de que upstream abandone el cliente, sino de que
una versión nueva del cliente rompa el protocolo antes de que headscale lo siga.
Eso es un trabajo permanente de upstream, no un defecto del enfoque.

**Por que no cambia la decisión:** el riesgo se puede controlar desde
Hefesto. El cliente Tailscale tiene actualización automática; en los servidores
del cliente se controla por versión. Un despliegue ordenado, con versión fijada
del cliente y prueba previa a cada salto, convierte un riesgo abierto en una
tarea programada.

Ademas, el riesgo es **reversible**. Si una versión del cliente rompe el
funcionamiento, se fija la versión anterior del cliente y se sigue operando. No
hay migración de datos ni estado en el cliente. El servidor de coordinacion no se
toca.

### 4.2 Lo que se pierde con esta decisión, dicho sin adornos

- **No hay consola web.** La administración es por linea de comandos. Para
  Hefesto es una ventaja (todo es automatizable). Para el cliente final es un
  costo: si el cliente quiere ver "quien esta conectado", no tiene un panel. Hay
  que ofrecerlo como parte del servicio o entregar consultas puntuales.
- **No hay MFA integrado.** Headscale no fuerza un segundo factor. La
  autenticación de los nodos es por clave pública de WireGuard. Ver
  `docs/08-SERVICIOS-COMERCIALES.md` para como suplir esa brecha.
- **No hay auditoria nativa de conexiones.** Headscale no entrega un registro de
  "quien entro, cuando y a que". Eso hay que construirlo con journald y las
  herramientas del sistema, como se explica en `docs/08-SERVICIOS-COMERCIALES.md`.
- **No hay doble cifrado de extremo a extremo** como el que ofrece NetBird con
  Signal. El trafico ya va cifrado con WireGuard entre los extremos, pero no hay
  una segunda capa.
- **Falta integración con reputacion de IP tipo CrowdSec.** No se documento
  porque no aplica a la opcion elegida. Se deja constancia aca para que quede
  claro que se evaluo y se descarto.

---

## 5. Conclusiones sobre licencias para este kit

1. **Headscale v0.29.5 es BSD 3-Clause.** Uso comercial, redistribucion y
   reventa permitidos. Único requisito: conservar el aviso de copyright y el
   texto de la licencia.
2. **Los clientes de los usuarios finales son aplicaciones oficiales de
   Tailscale**, con sus propios terminos de servicio. No se distribuyen ni se
   reempaquetan en este kit. Ese es un punto que debe quedar explicito en el
   contrato con el cliente: **la licencia de Headscale es propia del kit; la
   del cliente Tailscale es de Tailscale Inc. y no la controla Hefesto.**
3. **No se usa código de NetBird en este kit.** La comparacion fue documental.
4. Si en el futuro Hefesto migra a NetBird, debe rehacer esta evaluacion de
   licencias, porque el AGPLv3 alcanza justamente a los componentes de servidor.

---

## 6. Fuentes

Todas consultadas el 17 de octubre de 2026.

- Headscale, licencia, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/LICENSE>
- Headscale, configuración de ejemplo, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/config-example.yaml>
- Headscale, requisitos y puertos, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/docs/setup/requirements.md>
- Headscale, política de segmentacion, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/docs/ref/policy.md>
- Headscale, soporte de clientes, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/docs/about/clients.md>
- Headscale, instalación en contenedor, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/docs/setup/install/container.md>
- Headscale, build de la imagen, tag v0.29.5:
  <https://github.com/juanfont/headscale/blob/v0.29.5/.goreleaser.yml>
- Headscale, digests de imagen:
  <https://hub.docker.com/r/headscale/headscale/tags/0.29.5>
- NetBird, licencia, tag v0.81.2:
  <https://github.com/netbirdio/netbird/blob/v0.81.2/LICENSE>
- NetBird, compose oficial autoalojado, tag v0.81.2:
  <https://github.com/netbirdio/netbird/blob/v0.81.2/infrastructure_files/docker-compose.yml.tmpl>