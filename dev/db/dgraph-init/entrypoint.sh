#!/bin/bash

$UTILS/wait_for_db.sh

# Create schemas
echo "Creating Schemas"
curl --silent $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/admin/schema --data '
	type Company {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domains: [Domain]
	}

	type Domain {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		level: Int @search
		tld: Boolean @search
		subdomains: [Domain]

		skipScans: Boolean @search
		lastPassiveEnumeration: DateTime @search(by: [hour])
		lastActiveEnumeration: DateTime @search(by: [hour])
		lastProbe: DateTime @search(by: [hour])
		lastExploit: DateTime @search(by: [hour])

		foundBy: [Tool] @hasInverse(field: subdomains)
		dnsRecords: [DnsRecord] @hasInverse(field: domain)
		vulns: [Vuln] @hasInverse(field: domain)
	}

	type Tool {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		type: String! @search(by: [hash, regexp])
		subdomains: [Domain] @hasInverse(field: foundBy)
		vulns: [Vuln] @hasInverse(field: foundBy)
	}

	type DnsRecord {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: dnsRecords)
		type: String! @search(by: [hash])
		values: [String!]! @search(by: [hash, regexp])
		updatedAt: DateTime @search(by: [hour])
	}

	type Vuln {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: vulns)
		title: String! @search(by: [hash, regexp])
		class: VulnClass @hasInverse(field: vulns)
		description: String @search(by: [hash, regexp])
		severity: String @search(by: [hash])
		references: [String] @search(by: [hash, regexp])
		evidence: Evidence
		foundBy: [Tool] @hasInverse(field: vulns)
		updatedAt: DateTime @search(by: [hour])
	}

	type VulnClass {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		vulns: [Vuln] @hasInverse(field: class)
	}

	type Evidence {
		id: ID!
		target: String
		request: String
		response: String
	}
' | jq -c .

mkdir /tmp/domains
python3 $UTILS/parse_companies.py -f /src/data/companies.json -o /tmp/domains

for company_domains_file in /tmp/domains/*; do
	company=$(echo "$company_domains_file" | awk -F/ '{print $NF}' | awk -F. '{print $1}')
	echo "[$company] Creating company"
	$UTILS/save_company.sh -c "$company" -f "$company_domains_file" | jq -c .
done


echo "Creating Top Level Domains"
$UTILS/save_domains.sh -f <(echo '
name,tld
aaa,true
aarp,true
abb,true
abbott,true
abbvie,true
abc,true
able,true
abogado,true
abudhabi,true
ac,true
academy,true
accenture,true
accountant,true
accountants,true
aco,true
actor,true
ad,true
ads,true
adult,true
ae,true
aeg,true
aero,true
aetna,true
af,true
afl,true
africa,true
ag,true
agakhan,true
agency,true
ai,true
aig,true
airbus,true
airforce,true
airtel,true
akdn,true
al,true
allfinanz,true
allstate,true
ally,true
alsace,true
alstom,true
am,true
amazon,true
americanexpress,true
americanfamily,true
amex,true
amfam,true
amica,true
amsterdam,true
analytics,true
android,true
anquan,true
anz,true
ao,true
aol,true
apartments,true
app,true
apple,true
aq,true
aquarelle,true
ar,true
arab,true
aramco,true
archi,true
army,true
arpa,true
art,true
arte,true
as,true
asda,true
asia,true
associates,true
at,true
athleta,true
attorney,true
au,true
auction,true
audi,true
audible,true
audio,true
auspost,true
author,true
auto,true
autos,true
avianca,true
aw,true
aws,true
ax,true
axa,true
az,true
azure,true
ba,true
baby,true
baidu,true
banamex,true
bananarepublic,true
band,true
bank,true
bar,true
barcelona,true
barclaycard,true
barclays,true
barefoot,true
bargains,true
baseball,true
basketball,true
bauhaus,true
bayern,true
bb,true
bbc,true
bbt,true
bbva,true
bcg,true
bcn,true
bd,true
be,true
beats,true
beauty,true
beer,true
bentley,true
berlin,true
best,true
bestbuy,true
bet,true
bf,true
bg,true
bh,true
bharti,true
bi,true
bible,true
bid,true
bike,true
bing,true
bingo,true
bio,true
biz,true
bj,true
black,true
blackfriday,true
blockbuster,true
blog,true
bloomberg,true
blue,true
bm,true
bms,true
bmw,true
bn,true
bnpparibas,true
bo,true
boats,true
boehringer,true
bofa,true
bom,true
bond,true
boo,true
book,true
booking,true
bosch,true
bostik,true
boston,true
bot,true
boutique,true
box,true
br,true
bradesco,true
bridgestone,true
broadway,true
broker,true
brother,true
brussels,true
bs,true
bt,true
build,true
builders,true
business,true
buy,true
buzz,true
bv,true
bw,true
by,true
bz,true
bzh,true
ca,true
cab,true
cafe,true
cal,true
call,true
calvinklein,true
cam,true
camera,true
camp,true
canon,true
capetown,true
capital,true
capitalone,true
car,true
caravan,true
cards,true
care,true
career,true
careers,true
cars,true
casa,true
case,true
cash,true
casino,true
cat,true
catering,true
catholic,true
cba,true
cbn,true
cbre,true
cbs,true
cc,true
cd,true
center,true
ceo,true
cern,true
cf,true
cfa,true
cfd,true
cg,true
ch,true
chanel,true
channel,true
charity,true
chase,true
chat,true
cheap,true
chintai,true
christmas,true
chrome,true
church,true
ci,true
cipriani,true
circle,true
cisco,true
citadel,true
citi,true
citic,true
city,true
cityeats,true
ck,true
cl,true
claims,true
cleaning,true
click,true
clinic,true
clinique,true
clothing,true
cloud,true
club,true
clubmed,true
cm,true
cn,true
co,true
coach,true
codes,true
coffee,true
college,true
cologne,true
com,true
comcast,true
commbank,true
community,true
company,true
compare,true
computer,true
comsec,true
condos,true
construction,true
consulting,true
contact,true
contractors,true
cooking,true
cool,true
coop,true
corsica,true
country,true
coupon,true
coupons,true
courses,true
cpa,true
cr,true
credit,true
creditcard,true
creditunion,true
cricket,true
crown,true
crs,true
cruise,true
cruises,true
cu,true
cuisinella,true
cv,true
cw,true
cx,true
cy,true
cymru,true
cyou,true
cz,true
dabur,true
dad,true
dance,true
data,true
date,true
dating,true
datsun,true
day,true
dclk,true
dds,true
de,true
deal,true
dealer,true
deals,true
degree,true
delivery,true
dell,true
deloitte,true
delta,true
democrat,true
dental,true
dentist,true
desi,true
design,true
dev,true
dhl,true
diamonds,true
diet,true
digital,true
direct,true
directory,true
discount,true
discover,true
dish,true
diy,true
dj,true
dk,true
dm,true
dnp,true
do,true
docs,true
doctor,true
dog,true
domains,true
dot,true
download,true
drive,true
dtv,true
dubai,true
dunlop,true
dupont,true
durban,true
dvag,true
dvr,true
dz,true
earth,true
eat,true
ec,true
eco,true
edeka,true
edu,true
education,true
ee,true
eg,true
email,true
emerck,true
energy,true
engineer,true
engineering,true
enterprises,true
epson,true
equipment,true
er,true
ericsson,true
erni,true
es,true
esq,true
estate,true
et,true
etisalat,true
eu,true
eurovision,true
eus,true
events,true
exchange,true
expert,true
exposed,true
express,true
extraspace,true
fage,true
fail,true
fairwinds,true
faith,true
family,true
fan,true
fans,true
farm,true
farmers,true
fashion,true
fast,true
fedex,true
feedback,true
ferrari,true
ferrero,true
fi,true
fidelity,true
fido,true
film,true
final,true
finance,true
financial,true
fire,true
firestone,true
firmdale,true
fish,true
fishing,true
fit,true
fitness,true
fj,true
fk,true
flickr,true
flights,true
flir,true
florist,true
flowers,true
fly,true
fm,true
fo,true
foo,true
food,true
football,true
ford,true
forex,true
forsale,true
forum,true
foundation,true
fox,true
fr,true
free,true
fresenius,true
frl,true
frogans,true
frontdoor,true
frontier,true
ftr,true
fujitsu,true
fun,true
fund,true
furniture,true
futbol,true
fyi,true
ga,true
gal,true
gallery,true
gallo,true
gallup,true
game,true
games,true
gap,true
garden,true
gay,true
gb,true
gbiz,true
gd,true
gdn,true
ge,true
gea,true
gent,true
genting,true
george,true
gf,true
gg,true
ggee,true
gh,true
gi,true
gift,true
gifts,true
gives,true
giving,true
gl,true
glass,true
gle,true
global,true
globo,true
gm,true
gmail,true
gmbh,true
gmo,true
gmx,true
gn,true
godaddy,true
gold,true
goldpoint,true
golf,true
goo,true
goodyear,true
goog,true
google,true
gop,true
got,true
gov,true
gp,true
gq,true
gr,true
grainger,true
graphics,true
gratis,true
green,true
gripe,true
grocery,true
group,true
gs,true
gt,true
gu,true
guardian,true
gucci,true
guge,true
guide,true
guitars,true
guru,true
gw,true
gy,true
hair,true
hamburg,true
hangout,true
haus,true
hbo,true
hdfc,true
hdfcbank,true
health,true
healthcare,true
help,true
helsinki,true
here,true
hermes,true
hiphop,true
hisamitsu,true
hitachi,true
hiv,true
hk,true
hkt,true
hm,true
hn,true
hockey,true
holdings,true
holiday,true
homedepot,true
homegoods,true
homes,true
homesense,true
honda,true
horse,true
hospital,true
host,true
hosting,true
hot,true
hotels,true
hotmail,true
house,true
how,true
hr,true
hsbc,true
ht,true
hu,true
hughes,true
hyatt,true
hyundai,true
ibm,true
icbc,true
ice,true
icu,true
id,true
ie,true
ieee,true
ifm,true
ikano,true
il,true
im,true
imamat,true
imdb,true
immo,true
immobilien,true
in,true
inc,true
industries,true
infiniti,true
info,true
ing,true
ink,true
institute,true
insurance,true
insure,true
int,true
international,true
intuit,true
investments,true
io,true
ipiranga,true
iq,true
ir,true
irish,true
is,true
ismaili,true
ist,true
istanbul,true
it,true
itau,true
itv,true
jaguar,true
java,true
jcb,true
je,true
jeep,true
jetzt,true
jewelry,true
jio,true
jll,true
jm,true
jmp,true
jnj,true
jo,true
jobs,true
joburg,true
jot,true
joy,true
jp,true
jpmorgan,true
jprs,true
juegos,true
juniper,true
kaufen,true
kddi,true
ke,true
kerryhotels,true
kerrylogistics,true
kerryproperties,true
kfh,true
kg,true
kh,true
ki,true
kia,true
kids,true
kim,true
kinder,true
kindle,true
kitchen,true
kiwi,true
km,true
kn,true
koeln,true
komatsu,true
kosher,true
kp,true
kpmg,true
kpn,true
kr,true
krd,true
kred,true
kuokgroup,true
kw,true
ky,true
kyoto,true
kz,true
la,true
lacaixa,true
lamborghini,true
lamer,true
lancaster,true
land,true
landrover,true
lanxess,true
lasalle,true
lat,true
latino,true
latrobe,true
law,true
lawyer,true
lb,true
lc,true
lds,true
lease,true
leclerc,true
lefrak,true
legal,true
lego,true
lexus,true
lgbt,true
li,true
lidl,true
life,true
lifeinsurance,true
lifestyle,true
lighting,true
like,true
lilly,true
limited,true
limo,true
lincoln,true
link,true
lipsy,true
live,true
living,true
lk,true
llc,true
llp,true
loan,true
loans,true
locker,true
locus,true
lol,true
london,true
lotte,true
lotto,true
love,true
lpl,true
lplfinancial,true
lr,true
ls,true
lt,true
ltd,true
ltda,true
lu,true
lundbeck,true
luxe,true
luxury,true
lv,true
ly,true
ma,true
madrid,true
maif,true
maison,true
makeup,true
man,true
management,true
mango,true
map,true
market,true
marketing,true
markets,true
marriott,true
marshalls,true
mattel,true
mba,true
mc,true
mckinsey,true
md,true
me,true
med,true
media,true
meet,true
melbourne,true
meme,true
memorial,true
men,true
menu,true
merckmsd,true
mg,true
mh,true
miami,true
microsoft,true
mil,true
mini,true
mint,true
mit,true
mitsubishi,true
mk,true
ml,true
mlb,true
mls,true
mm,true
mma,true
mn,true
mo,true
mobi,true
mobile,true
moda,true
moe,true
moi,true
mom,true
monash,true
money,true
monster,true
mormon,true
mortgage,true
moscow,true
moto,true
motorcycles,true
mov,true
movie,true
mp,true
mq,true
mr,true
ms,true
msd,true
mt,true
mtn,true
mtr,true
mu,true
museum,true
music,true
mv,true
mw,true
mx,true
my,true
mz,true
na,true
nab,true
nagoya,true
name,true
natura,true
navy,true
nba,true
nc,true
ne,true
nec,true
net,true
netbank,true
netflix,true
network,true
neustar,true
new,true
news,true
next,true
nextdirect,true
nexus,true
nf,true
nfl,true
ng,true
ngo,true
nhk,true
ni,true
nico,true
nike,true
nikon,true
ninja,true
nissan,true
nissay,true
nl,true
no,true
nokia,true
norton,true
now,true
nowruz,true
nowtv,true
np,true
nr,true
nra,true
nrw,true
ntt,true
nu,true
nyc,true
nz,true
obi,true
observer,true
office,true
okinawa,true
olayan,true
olayangroup,true
oldnavy,true
ollo,true
om,true
omega,true
one,true
ong,true
onl,true
online,true
ooo,true
open,true
oracle,true
orange,true
org,true
organic,true
origins,true
osaka,true
otsuka,true
ott,true
ovh,true
pa,true
page,true
panasonic,true
paris,true
pars,true
partners,true
parts,true
party,true
pay,true
pccw,true
pe,true
pet,true
pf,true
pfizer,true
pg,true
ph,true
pharmacy,true
phd,true
philips,true
phone,true
photo,true
photography,true
photos,true
physio,true
pics,true
pictet,true
pictures,true
pid,true
pin,true
ping,true
pink,true
pioneer,true
pizza,true
pk,true
pl,true
place,true
play,true
playstation,true
plumbing,true
plus,true
pm,true
pn,true
pnc,true
pohl,true
poker,true
politie,true
porn,true
post,true
pr,true
pramerica,true
praxi,true
press,true
prime,true
pro,true
prod,true
productions,true
prof,true
progressive,true
promo,true
properties,true
property,true
protection,true
pru,true
prudential,true
ps,true
pt,true
pub,true
pw,true
pwc,true
py,true
qa,true
qpon,true
quebec,true
quest,true
racing,true
radio,true
re,true
read,true
realestate,true
realtor,true
realty,true
recipes,true
red,true
redstone,true
redumbrella,true
rehab,true
reise,true
reisen,true
reit,true
reliance,true
ren,true
rent,true
rentals,true
repair,true
report,true
republican,true
rest,true
restaurant,true
review,true
reviews,true
rexroth,true
rich,true
richardli,true
ricoh,true
ril,true
rio,true
rip,true
ro,true
rocher,true
rocks,true
rodeo,true
rogers,true
room,true
rs,true
rsvp,true
ru,true
rugby,true
ruhr,true
run,true
rw,true
rwe,true
ryukyu,true
sa,true
saarland,true
safe,true
safety,true
sakura,true
sale,true
salon,true
samsclub,true
samsung,true
sandvik,true
sandvikcoromant,true
sanofi,true
sap,true
sarl,true
sas,true
save,true
saxo,true
sb,true
sbi,true
sbs,true
sc,true
sca,true
scb,true
schaeffler,true
schmidt,true
scholarships,true
school,true
schule,true
schwarz,true
science,true
scot,true
sd,true
se,true
search,true
seat,true
secure,true
security,true
seek,true
select,true
sener,true
services,true
seven,true
sew,true
sex,true
sexy,true
sfr,true
sg,true
sh,true
shangrila,true
sharp,true
shaw,true
shell,true
shia,true
shiksha,true
shoes,true
shop,true
shopping,true
shouji,true
show,true
showtime,true
si,true
silk,true
sina,true
singles,true
site,true
sj,true
sk,true
ski,true
skin,true
sky,true
skype,true
sl,true
sling,true
sm,true
smart,true
smile,true
sn,true
sncf,true
so,true
soccer,true
social,true
softbank,true
software,true
sohu,true
solar,true
solutions,true
song,true
sony,true
soy,true
spa,true
space,true
sport,true
spot,true
sr,true
srl,true
ss,true
st,true
stada,true
staples,true
star,true
statebank,true
statefarm,true
stc,true
stcgroup,true
stockholm,true
storage,true
store,true
stream,true
studio,true
study,true
style,true
su,true
sucks,true
supplies,true
supply,true
support,true
surf,true
surgery,true
suzuki,true
sv,true
swatch,true
swiss,true
sx,true
sy,true
sydney,true
systems,true
sz,true
tab,true
taipei,true
talk,true
target,true
tatamotors,true
tatar,true
tattoo,true
tax,true
taxi,true
tc,true
tci,true
td,true
tdk,true
team,true
tech,true
technology,true
tel,true
temasek,true
tennis,true
teva,true
tf,true
tg,true
th,true
thd,true
theater,true
theatre,true
tiaa,true
tickets,true
tienda,true
tips,true
tires,true
tirol,true
tj,true
tjmaxx,true
tjx,true
tk,true
tkmaxx,true
tl,true
tm,true
tn,true
to,true
today,true
tokyo,true
tools,true
top,true
toray,true
toshiba,true
total,true
tours,true
town,true
toyota,true
toys,true
tr,true
trade,true
trading,true
training,true
travel,true
travelers,true
travelersinsurance,true
trust,true
trv,true
tt,true
tube,true
tui,true
tunes,true
tushu,true
tv,true
tvs,true
tw,true
tz,true
ua,true
ubank,true
ubs,true
ug,true
uk,true
unicom,true
university,true
uno,true
uol,true
ups,true
us,true
uy,true
uz,true
va,true
vacations,true
vana,true
vanguard,true
vc,true
ve,true
vegas,true
ventures,true
verisign,true
versicherung,true
vet,true
vg,true
vi,true
viajes,true
video,true
vig,true
viking,true
villas,true
vin,true
vip,true
virgin,true
visa,true
vision,true
viva,true
vivo,true
vlaanderen,true
vn,true
vodka,true
volkswagen,true
volvo,true
vote,true
voting,true
voto,true
voyage,true
vu,true
wales,true
walter,true
wang,true
wanggou,true
watch,true
watches,true
weather,true
weatherchannel,true
webcam,true
weber,true
website,true
wed,true
wedding,true
weibo,true
weir,true
wf,true
whoswho,true
wien,true
wiki,true
williamhill,true
win,true
windows,true
wine,true
winners,true
wme,true
wolterskluwer,true
woodside,true
work,true
works,true
world,true
wow,true
ws,true
wtc,true
wtf,true
xbox,true
xerox,true
xfinity,true
xihuan,true
xin,true
xn--11b4c3d,true
xn--1ck2e1b,true
xn--1qqw23a,true
xn--2scrj9c,true
xn--30rr7y,true
xn--3bst00m,true
xn--3ds443g,true
xn--3e0b707e,true
xn--3hcrj9c,true
xn--3pxu8k,true
xn--42c2d9a,true
xn--45br5cyl,true
xn--45brj9c,true
xn--45q11c,true
xn--4dbrk0ce,true
xn--4gbrim,true
xn--54b7fta0cc,true
xn--55qw42g,true
xn--55qx5d,true
xn--5su34j936bgsg,true
xn--5tzm5g,true
xn--6frz82g,true
xn--6qq986b3xl,true
xn--80adxhks,true
xn--80ao21a,true
xn--80aqecdr1a,true
xn--80asehdb,true
xn--80aswg,true
xn--8y0a063a,true
xn--90a3ac,true
xn--90ae,true
xn--90ais,true
xn--9dbq2a,true
xn--9et52u,true
xn--9krt00a,true
xn--b4w605ferd,true
xn--bck1b9a5dre4c,true
xn--c1avg,true
xn--c2br7g,true
xn--cck2b3b,true
xn--cckwcxetd,true
xn--cg4bki,true
xn--clchc0ea0b2g2a9gcd,true
xn--czr694b,true
xn--czrs0t,true
xn--czru2d,true
xn--d1acj3b,true
xn--d1alf,true
xn--e1a4c,true
xn--eckvdtc9d,true
xn--efvy88h,true
xn--fct429k,true
xn--fhbei,true
xn--fiq228c5hs,true
xn--fiq64b,true
xn--fiqs8s,true
xn--fiqz9s,true
xn--fjq720a,true
xn--flw351e,true
xn--fpcrj9c3d,true
xn--fzc2c9e2c,true
xn--fzys8d69uvgm,true
xn--g2xx48c,true
xn--gckr3f0f,true
xn--gecrj9c,true
xn--gk3at1e,true
xn--h2breg3eve,true
xn--h2brj9c,true
xn--h2brj9c8c,true
xn--hxt814e,true
xn--i1b6b1a6a2e,true
xn--imr513n,true
xn--io0a7i,true
xn--j1aef,true
xn--j1amh,true
xn--j6w193g,true
xn--jlq480n2rg,true
xn--jvr189m,true
xn--kcrx77d1x4a,true
xn--kprw13d,true
xn--kpry57d,true
xn--kput3i,true
xn--l1acc,true
xn--lgbbat1ad8j,true
xn--mgb9awbf,true
xn--mgba3a3ejt,true
xn--mgba3a4f16a,true
xn--mgba7c0bbn0a,true
xn--mgbaakc7dvf,true
xn--mgbaam7a8h,true
xn--mgbab2bd,true
xn--mgbah1a3hjkrd,true
xn--mgbai9azgqp6j,true
xn--mgbayh7gpa,true
xn--mgbbh1a,true
xn--mgbbh1a71e,true
xn--mgbc0a9azcg,true
xn--mgbca7dzdo,true
xn--mgbcpq6gpa1a,true
xn--mgberp4a5d4ar,true
xn--mgbgu82a,true
xn--mgbi4ecexp,true
xn--mgbpl2fh,true
xn--mgbt3dhd,true
xn--mgbtx2b,true
xn--mgbx4cd0ab,true
xn--mix891f,true
xn--mk1bu44c,true
xn--mxtq1m,true
xn--ngbc5azd,true
xn--ngbe9e0a,true
xn--ngbrx,true
xn--node,true
xn--nqv7f,true
xn--nqv7fs00ema,true
xn--nyqy26a,true
xn--o3cw4h,true
xn--ogbpf8fl,true
xn--otu796d,true
xn--p1acf,true
xn--p1ai,true
xn--pgbs0dh,true
xn--pssy2u,true
xn--q7ce6a,true
xn--q9jyb4c,true
xn--qcka1pmc,true
xn--qxa6a,true
xn--qxam,true
xn--rhqv96g,true
xn--rovu88b,true
xn--rvc1e0am3e,true
xn--s9brj9c,true
xn--ses554g,true
xn--t60b56a,true
xn--tckwe,true
xn--tiq49xqyj,true
xn--unup4y,true
xn--vermgensberater-ctb,true
xn--vermgensberatung-pwb,true
xn--vhquv,true
xn--vuq861b,true
xn--w4r85el8fhu5dnra,true
xn--w4rs40l,true
xn--wgbh1c,true
xn--wgbl6a,true
xn--xhq521b,true
xn--xkc2al3hye2a,true
xn--xkc2dl3a5ee0h,true
xn--y9a3aq,true
xn--yfro4i67o,true
xn--ygbi2ammx,true
xn--zfr164b,true
xxx,true
xyz,true
yachts,true
yamaxun,true
yandex,true
ye,true
yodobashi,true
yoga,true
yokohama,true
you,true
yt,true
yun,true
za,true
zappos,true
zara,true
zero,true
zip,true
zm,true
zone,true
zuerich,true
zw,true
')
