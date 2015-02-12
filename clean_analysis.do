capture log close

clear
set more off, permanently

log using bhps_clear, text replace

/*MERGE ALL 18 WAVES FROM ORIGINAL DATA*/

**append waves

global chars a b c d e f g h i j k l m n o p q r

foreach w of newlist $chars {
 use `w'indresp.dta, clear

 global vars `w'frn* `w'op* `w'bwt* `w'hls* `w'jbisco* `w'jlisco* `w'mrj* `w'paiscon `w'maiscon `w'j1* `w'movjb* `w'edfee* `w'trfee* `w'trq* `w'coh* `w'vote* `w'lac* `w'nfh* `w'edql* `w'edoql* `w'trql* `w'net* `w'wem* `w'ln*
 **drop variables

 foreach v of global vars {
  capture drop `v'
 }

 rename `w'* *
 save `w'bhps.dta, replace
}

global bhps
foreach w of newlist $chars  {
 global bhps $bhps `w'bhps.dta
}
append using $bhps, gen(srcwave)
drop if srcwave == 0

save bhps_big.dta, replace

/*DATA CLEAN UP AND PREPARATION FOR ANALYSIS*/

drop ocim* fut* ql* nati* ed* fthh* fimn*i  fimnsel prf1* prfirn prfitb rtfnd* rdsbn16-rdsbn25 iv* nqf* hlp* adl* jbst1* jben* satinv ptrt5* svack* trwhy* aid* lwsen* lwss* jss* jsen* lwst* lwen* lwsd* lwdn* rtrly* rtlat* rtpro* rtcon*

***set up
gen year = srcwave + 1990
gen cpiyear = year
replace pid = id if year == 2006
sort pid year
drop if year == 1990

***Demographics
*age
drop if age < 21
*gender
mvdecode sex, mv(-7)
gen female = (sex == 2) if sex != .
drop sex hgsex ssup1
*marital status
mvdecode mlstat, mv(-9/-1)
gen married = (mlstat == 1 | mlstat == 6) if mlstat != .
drop mastat
*ethnicity
mvdecode race, mv(-9/-2)
gen black = inrange(race, 2, 4) if race != .
gen asian = inrange(race, 5, 8) if race != .
mvdecode racel, mv(-9/-1)
replace black = inrange(racel, 14, 16) if racel != .
replace asian = inrange(racel, 10, 13) if racel != .
/*race coded only for the first time person was interviewed*/
by pid: replace black = black[1] if black == .
by pid: replace asian = asian[1] if asian == .
drop race racel
*number of dependent children
gen nokids = (nchild == 0) if nchild != .
*where they live
mvdecode region region2, mv(-9)
mvdecode region2, mv(13) //remove channel islands
decode region2, gen(regname)
gen London = inrange(region, 1, 2) if region != .
gen Wales = region == 17 if region != .
gen Scotland = region == 18 if region != .
gen NIrl = region == 19 if region != .
global regions London Wales Scotland NIrl
*place of birth
mvdecode plbornc, mv(-9,-7)
gen bornAway = plbornc != -8 if plbornc != .
mvdecode plbornd, mv(-9/0)
sort pid year
by pid: replace bornAway = bornAway[1] if bornAway[1] != .

***education
mvdecode isced, mv(-7,0)
gen uni = isced > 5 if isced != .
tab isced, gen(educ)
recode isced (1 = 6) (6 = 16) (7 = 19) (5 = 15) (4 = 13) (3 = 11) (2 = 10), gen(edyears)


***labor force status and employment
drop nemst
mvdecode jbstat, mv(-9/-1)
gen inLF = inrange(jbstat, 1, 3) | jbstat == 9 if jbstat != .
gen employee = jbstat == 2 if jbstat != . & inLF == 1
gen selfemp = jbstat == 1 if jbstat != . & inLF == 1
gen unemp = jbstat == 3 if jbstat != . & inLF == 1
gen retired = jbstat == 4 if jbstat != . 
by pid: gen newSelfemp = (selfemp == 1 & selfemp[_n-2] == 0) if selfemp != . & selfemp[_n-2] != .
by pid: gen selfPersist = (selfemp == 1 & newSelfemp[_n-1] == 1) if selfemp != . & newSelfemp[_n-1] != .
by pid: gen selfDrop = (selfemp == 0 & newSelfemp[_n-1] == 1) if selfemp != . & newSelfemp[_n-1] != .
by pid: gen selfPersist2 = (selfemp == 1 & newSelfemp[_n-2] == 1) if selfemp != . & newSelfemp[_n-2] != .
by pid: gen selfDrop2 = (selfemp == 0 & newSelfemp[_n-2] == 1) if selfemp != . & newSelfemp[_n-2] != .
sort year
by year: egen urate = mean(unemp)
*self employment type
mvdecode jsboss, mv(-9/-1)
gen employer = jsboss == 1 if jsboss != . & selfemp == 1
gen ownaccount = jsboss == 2 if jsboss != . & selfemp == 1
sort pid year
by pid: gen newBoss = (employer == 1 & employer[_n-2] == 0) if employer != . & employer[_n-2] != .
by pid: gen newOwn = (ownaccount == 1 & selfemp[_n-2] == 0) if ownaccount != . & selfemp[_n-2] != .
by pid: gen newFirm = (employer == 1 & selfemp[_n-2] == 0) if employer != . & selfemp[_n-2] != .

*categorical variable (0, 1, 2, 3)
gen workstat = 1 if unemp == 1
replace workstat = 2 if employee == 1
replace workstat = 3 if selfemp == 1
replace workstat = 4 if retired == 1
*tenure
sort pid year
by pid: egen tenure_emp = sum(employee)
by pid: egen tenure_self = sum(selfemp)
mvdecode jbbgy, mv(-9/-1)
replace jbbgy = jbbgy + 1900
gen jobtenure = year - jbbgy
by pid: replace tenure_emp = tenure_emp + jobtenure[1] if employee[1] == 1
by pid: replace tenure_self = tenure_self + jobtenure[1] if selfemp[1] == 1
*industry
mvdecode jbsic jbsic92, mv(-9/0)
gen industry = jbsic if jbsic != .
replace industry = jbsic92 if jbsic92 != .
replace industry = floor(industry/1000)
tab industry if industry != ., gen(ind)

*parental history of employment
mvdecode pasemp, mv(-9/-1)
mvdecode masemp, mv(-9/-1)
gen f_selfemp = pasemp == 2 if pasemp != .
gen m_selfemp = masemp == 2 if masemp != .
sort pid year
/*coded only for first responders*/
by pid: replace f_selfemp = f_selfemp[1] if f_selfemp == .
by pid: replace m_selfemp = m_selfemp[1] if m_selfemp == .
*hours worked
mvdecode jbhrs, mv(-9/-1)
gen hrs_emp = jbhrs if employee == 1
mvdecode jshrs, mv(-9/-1)
gen hrs_self = jshrs if selfemp == 1

gen hrs_wrkd = hrs_emp
replace hrs_wrkd = hrs_self if selfemp == 1

***income
*load CPI index from ONS
merge m:1 cpiyear using uk_cpi
drop if _merge==2
drop _merge

*correct for inflation
global monetary fiyr* fimn* paygu paygl paygyr paynl pywftc payu payug extrate basrate ovtrate jbonam jsprf jsprof jspayu jspayg xpchc jupayx jupayl j2pay saved windf*y xpmeal xpleis  windfy

foreach var of varlist $monetary {
	mvdecode `var', mv(-9/-1)
	replace `var' = `var' / (cpi/100)
}

**income from employment, self employment, unemployment
*self employment

//jsprf for profit share, jspayg for usual self employed pay monthly
replace jsprf = 0 if jsprf == . & selfemp == 1 & jspayg != .
replace jspayg = 0 if jsprf != . & selfemp == 1 & jspayg == .
gen hwage_self = ((jsprf/52) + (jspayg/4.3))/hrs_self
gen inc_self = jsprf + jspayg*12 //annual income
gen inc_employer = inc_self if employer == 1
gen inc_own = inc_self if ownaccount == 1

*employment

//paygu for gross pay per month
gen hwage_emp = paygu/4.3/hrs_emp
gen inc_emp = paygu*12

***retirement
*health
mvdecode hllt, mv(-9/-1)
gen health_limit = (hllt == 1) if hllt != .
*age of retirement
mvdecode agexrt, mv(-9/-1)
*pensions are fiyrp fimnp (annual/monthly)
sort pid year
by pid: gen pensionUp = 0
by pid: replace pensionUp = 1 if fiyrp[_n-1] == 0 & fiyrp[_n] > 0 & fiyrp != .
by pid: replace pensionUp = 1 if fiyrp[1] > 0 & fiyrp[1] != . & _n == 1
by pid: egen pensionCheck = sum(pensionUp)
gen willPensionUp = pensionCheck > 0 if pensionCheck != .
gen retirYear = year if pensionUp == 1
by pid: egen firstRetired = min(retirYear)
gen hasRetired = 0
replace hasRetired = 1 if year >= firstRetired & firstRetired != .

gen newretir = 0
by pid: replace newretir = 1 if retired == 1 & retired[_n-1] == 0

gen newretirB = 0
by pid: replace newretirB = 1 if hasRetired == 1 & hasRetired[_n-1] == 0

*use past industry
foreach var of varlist ind* {
	by pid: replace `var' = `var'[_n-1] if retired == 1 & `var' == .
}


***windfall income

mvdecode windf, mv(-9/-1)
gen hadWindfall = (windf == 1) if windf != .
global windY windf*y

/*want to turn missing values to zero to allow summations*/
mvencode $windY, mv(-1)
foreach var of varlist $windY {
	replace `var' = 0 if `var' == -1
	gen has_`var' = `var' > 0
}
gen windfall = windfay + windfby + windfcy + windfdy + windffy + windfgy + windfhy + windfiy + windfy
/*correcting for years where no windfall data was collected*/
replace windfall = . if inrange(year, 1992,1995) | year == 1997


*log incomess
foreach var of varlist inc_* windfall {
	cap gen ln_`var' = ln(`var'+1) if `var' != .
}

foreach var of varlist windf*y {
	gen ln_`var' = ln(`var'+1)
	gen k_`var' = `var'/1000
	gen `var'5 = (`var' > 5000) if `var' != .
}


global personal L.married black asian female ind2-ind10 L.London L.Wales L.Scotland L.NIrl L.m_selfemp L.f_selfemp L.health_limit bornAway L.nokids

***logs and other variables needed
gen ln_schooling = ln(edyears)
gen ln_tenure_emp = ln(tenure_emp)
gen ln_tenure_self = ln(tenure_self)
gen ln_tenure_diff = ln_tenure_self - ln_tenure_emp
gen ln_hrs = ln(hrs_wrkd)
gen ln_age = ln(age)
gen ln_pension = ln(fiyrp)
gen k_windfall = windfall/1000
gen k_pension = fiyrp/1000
gen windfall5 = (windfall > 5000) if windfall != .
gen windfall0 = (windfall <= 1000) if windfall != .
sort pid year
by pid: egen k_avgpension = mean(k_pension) if year >= firstRetired
by pid: replace k_avgpension = 0 if year < firstRetired

save bhps_clean.dta, replace

/*DATASET IS NOW READY FOR ANALYSIS*/

xtset pid year 

/*DESCRIPTIVE STATS*/

sum age married black asian female edyears nchild bornAway
sum age married black asian female edyears nchild bornAway if employee == 1
sum age married black asian female edyears nchild bornAway if unemp == 1 
sum age married black asian female edyears nchild bornAway if selfemp == 1
sum age married black asian female edyears nchild bornAway if retired == 1
sum age married black asian female edyears nchild bornAway if newSelfemp == 1

sum fiyr health_limit *_selfemp London Scotland
sum fiyr health_limit *_selfemp London Scotland if employee == 1
sum fiyr health_limit *_selfemp London Scotland if unemp == 1
sum fiyr health_limit *_selfemp London Scotland if selfemp == 1
sum fiyr health_limit *_selfemp London Scotland if retired == 1
sum fiyr health_limit *_selfemp London Scotland if newSelfemp == 1

gen workstat2 = L2.workstat

tab workstat2 workstat , row

sum newSelfemp
sum newSelfemp if L.windfall > 0 & L.windfall != .
sum newSelfemp if inrange(L.windfall, 0.01, 1000) & L.windfall != .
sum newSelfemp if inrange(L.windfall, 1000, 5000) & L.windfall != .
sum newSelfemp if L.windfall > 5000 & L.windfall != .

sum newSelfemp if L.pensionUp == 1 & L.pensionUp != .
sum newSelfemp if L.pensionUp == 0 & L.pensionUp != .

**selfemployment around retirement

by pid: gen jbstat1 = jbstat[_n-1]
by pid: gen jbstat2 = jbstat[_n-2]
by pid: gen jbstat3 = jbstat[_n-3]

tab jbstat3 if pensionUp == 1 & newretir != .
tab jbstat2 if pensionUp == 1 & newretir != .
tab jbstat1 if pensionUp == 1 & newretir != .
tab jbstat if pensionUp == 1 & newretir != .
tab jbstat if L.pensionUp == 1 & L.newretir != .
tab jbstat if L2.pensionUp == 1 & L2.newretir !=.
tab jbstat if L3.pensionUp == 1 & L2.newretir !=.

tab jbstat3 if newretirB == 1 & newretir != .
tab jbstat2 if newretirB == 1 & newretir != .
tab jbstat1 if newretirB == 1 & newretir != .
tab jbstat if newretirB == 1 & newretir != .
tab jbstat if L.newretirB == 1 & L.newretir != .
tab jbstat if L2.newretirB == 1 & L2.newretir !=.
tab jbstat if L3.newretirB == 1 & L2.newretir !=.

/*RETIREMENT MODEL*/


reg newSelfemp L.pensionUp L.k_pension L.ln_tenure_diff L.age L.edyears $personal , r
reg newSelfemp L.pensionUp L.k_avgpension $personal L.edyears L.ln_tenure_diff L.age L.k_pension, r
probit newSelfemp L.pensionUp $personal L.edyears L.ln_tenure_diff L.age L.k_pension, r
margins, dydx(L1.pensionUp L1.k_pension L1.ln_tenure_diff)
probit newSelfemp L.pensionUp L.k_avgpension $personal L.edyears L.ln_tenure_diff L.age L.k_pension, r
margins, dydx(L1.pensionUp L1.k_pension L1.k_avgpension L1.ln_tenure_diff )

*different definitions of newretir

probit newSelfemp L.newretir $personal L.edyears L.ln_tenure_diff L.age L.k_pension L.k_avgpension, r
margins, dydx(L1.newretir L1.k_pension L1.k_avgpension L1.ln_tenure_diff )
probit newSelfemp L.newretirB L.k_pension L.ln_tenure_diff L.age L.edyears L.k_avgpension $personal , r
margins, dydx(L1.newretirB L1.k_pension L1.k_avgpension L1.ln_tenure_diff )

probit newSelfemp L.pensionUp L.k_pension L.ln_tenure_diff L.age L.edyears L.k_avgpension $personal , r

*different transitions (own account or employer)
probit newOwn L.pensionUp $personal L.edyears L.ln_tenure_diff L.age L.k_pension L.k_avgpension, r
margins, dydx(L1.pensionUp L1.k_pension L1.k_avgpension L1.ln_tenure_diff )
probit newFirm L.pensionUp $personal L.edyears L.ln_tenure_diff L.age L.k_pension L.k_avgpension, r
margins, dydx(L1.pensionUp L1.k_pension L1.k_avgpension L1.ln_tenure_diff )

*persistence
reg selfPersist L2.pensionUp $personal L.edyears L2.ln_tenure_diff L2.age L.k_pension L.k_avgpension, r
probit selfPersist L2.pensionUp $personal L.edyears L2.ln_tenure_diff L2.age L.k_pension L.k_avgpension, r
reg selfDrop L2.pensionUp $personal L.edyears L2.ln_tenure_diff L2.age L.k_pension L.k_avgpension, r
probit selfDrop L2.pensionUp $personal L.edyears L2.ln_tenure_diff L2.age L.k_pension L.k_avgpension, r

reg selfPersist2 L3.pensionUp $personal L.edyears L3.ln_tenure_diff L3.age L.k_pension L.k_avgpension, r
probit selfPersist2 L3.pensionUp $personal L.edyears L3.ln_tenure_diff L3.age L.k_pension L.k_avgpension, r
reg selfDrop2 L3.pensionUp $personal L.edyears L3.ln_tenure_diff L3.age L.k_pension L.k_avgpension, r
probit selfDrop2 L3.pensionUp $personal L.edyears L3.ln_tenure_diff L3.age L.k_pension L.k_avgpension, r


/*WINDFAL MODEL*/

***Heckman correction
*employment
heckman ln_inc_emp L.ln_schooling L.ln_tenure_emp L.ln_age L.ln_hrs $personal, select(employee = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.k_windfdy L.k_windfay L.k_windfcy L.k_windfhy L.k_windfgy L.k_windffy L.k_windfiy) twostep
predict expinc_emp_np

heckman ln_inc_emp L.ln_schooling L.ln_tenure_emp L.ln_age L.ln_hrs $personal, select(employee = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy) twostep
predict expinc_emp_npl

heckman ln_inc_emp L.ln_schooling L.ln_tenure_emp L.ln_age L.ln_hrs $personal, select(employee = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.has_windfdy L.has_windfay L.has_windfcy L.has_windfhy L.has_windfgy L.has_windffy L.has_windfiy) twostep
predict expinc_emp_npd

heckman ln_inc_emp L.ln_schooling L.ln_tenure_emp L.ln_age L.ln_hrs $personal, select(employee = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.windfdy5 L.windfay5 L.windfcy5 L.windfhy5 L.windfgy5 L.windffy5 L.windfiy5) twostep
predict expinc_emp_np5

*selfemployment
//amounts
heckman ln_inc_self L.ln_schooling L.ln_tenure_self L.ln_age L.ln_hrs $personal, select(selfemp = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.k_windfdy L.k_windfay L.k_windfcy L.k_windfhy L.k_windfgy L.k_windffy L.k_windfiy) twostep
predict expinc_self_np
//amounts in logs
heckman ln_inc_self L.ln_schooling L.ln_tenure_self L.ln_age L.ln_hrs $personal, select(selfemp = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy) twostep
predict expinc_self_npl
//dummies
heckman ln_inc_self L.ln_schooling L.ln_tenure_self L.ln_age L.ln_hrs $personal, select(selfemp = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.has_windfdy L.has_windfay L.has_windfcy L.has_windfhy L.has_windfgy L.has_windffy L.has_windfiy) twostep
predict expinc_self_npd
//above 5k
heckman ln_inc_self L.ln_schooling L.ln_tenure_self L.ln_age L.ln_hrs $personal, select(selfemp = $personal L.ln_schooling L.ln_tenure_diff L.ln_age L.windfdy5 L.windfay5 L.windfcy5 L.windfhy5 L.windfgy5 L.windffy5 L.windfiy5) twostep
predict expinc_self_np5

***Selection
gen expinc_diff_np = expinc_self_np - expinc_emp_np
reg newSelfemp L.expinc_diff_np L.k_windfdy L.k_windfay L.k_windfcy L.k_windfhy L.k_windfgy L.k_windffy L.k_windfiy $personal, r
probit newSelfemp L.expinc_diff_np L.k_windfdy L.k_windfay L.k_windfcy L.k_windfhy L.k_windfgy L.k_windffy L.k_windfiy $personal, r
margins, dydx(L.expinc_diff_np L.k_windfdy L.k_windfay L.k_windfcy L.k_windfhy L.k_windfgy L.k_windffy L.k_windfiy)

*with logs
gen expinc_diff_npl = expinc_self_npl - expinc_emp_npl
reg newSelfemp L.expinc_diff_npl L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy $personal, r
probit newSelfemp L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy $personal, r
margins, dydx(L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy)

*with dummies
gen expinc_diff_npd = expinc_self_npd - expinc_emp_npd
reg newSelfemp L.expinc_diff_npd L.has_windfdy L.has_windfay L.has_windfcy L.has_windfhy L.has_windfgy L.has_windffy L.has_windfiy $personal, r
probit newSelfemp L.expinc_diff_npd L.has_windfdy L.has_windfay L.has_windfcy L.has_windfhy L.has_windfgy L.has_windffy L.has_windfiy $personal, r
margins, dydx(L.expinc_diff_npd L.has_windfdy L.has_windfay L.has_windfcy L.has_windfhy L.has_windfgy L.has_windffy L.has_windfiy)

*over 5000
gen expinc_diff_np5 = expinc_self_np5 - expinc_emp_np5
reg newSelfemp L.expinc_diff_np5  L.windfdy5 L.windfay5 L.windfcy5 L.windfhy5 L.windfgy5 L.windffy5 L.windfiy5 $personal, r
probit newSelfemp L.expinc_diff_np5  L.windfdy5 L.windfay5 L.windfcy5 L.windfhy5 L.windfgy5 L.windffy5 L.windfiy5 $personal, r
margins, dydx(L.expinc_diff_np5  L.windfdy5 L.windfay5 L.windfcy5 L.windfhy5 L.windfgy5 L.windffy5 L.windfiy5)

*different transitions
probit newOwn L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy $personal, r
margins, dydx(L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy)
probit newFirm L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy $personal, r
margins, dydx(L.expinc_diff_npl  L.ln_windfdy L.ln_windfay L.ln_windfcy L.ln_windfhy L.ln_windfgy L.ln_windffy L.ln_windfiy)

capture log close 

