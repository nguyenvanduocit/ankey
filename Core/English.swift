import Foundation

/// English words that Telex would turn into a real Vietnamese syllable (`reset` → `rết`).
///
/// Source: the 20k most frequent words of google-10000-english (github.com/first20hours/google-10000-english),
/// kept when the engine converts them and the word has three letters or more. Shorter ones are Telex
/// itself: `aj` is `ạ`, `oo` is `ô`. Each word falls in a band by how common its converted form is in
/// Vietnamese, ranked by hermitdave/FrequencyWords (vi, 2018):
///   - under 500: left out, the Vietnamese word wins (`cos` is `có`, `nos` is `nó`);
///   - 500 to 8000: `context`, English only right after an English word (`last` is `lát`, `chaos` is `cháo`);
///   - 8000 and up, or not ranked: `always`, English everywhere (`reset` is not `rết`).
/// Placed by hand: `test`, `list`, `box`, `asap` and the short words people used to list themselves go to
/// `always`, and `as`, `car`, `too`, `own`, `var`, `max`, `ref`, `docs` and the rest of the old pairs stay in `context`.
/// The built-in list lives in code, not in `UserDefaults`, so an update reaches users who already saved settings.
enum English {
    /// Typed keys, lowercase.
    static let always: Set<String> = Set(alwaysSource.split(whereSeparator: \.isWhitespace).map(String.init))
    static let context: Set<String> = Set(contextSource.split(whereSeparator: \.isWhitespace).map(String.init))
}

private let alwaysSource = """
aac aca apa asap ata bays beech best bins bono boom boot born bots bows box bur burn burns busy
buys caa cary chairs charm chars charts chats cheer choir chose chow coco como cons coop cops corn
corps cosmos cost costs cox dar darn darts das data dawn dems des dex dir disc discs dist donors
doom door doors doris dots downs dust ecs een ems ers esc est gaps gary gifs gis goto gown gus
guts haas hamas harm has hays her here hex hips his honors hoop horn horns horse horses hose host
hosts how huns ics if inf ins is keen keep kern kits kos laps law laws lays les lips lisa lisp
list lists loans lois loop lore loren lose loser losers loses lows luis majors mana manga mans mar
mary meet meets mens mes meters mips mis misc mix moms most mus napa nas nero nis noir nor norm
now nox nur of ons oops ops or ora ore osx pans par parts pas past paw pee peers pers peso pesos
pest pests pete peters pets photo photos pics pits pow queens queue ras raw rays reef res rest
rims roms room root ros rosa row rows runs rus sar sars sas sata saw saws sax sees ses sins sis
sits six soar sofa sofas sons soon sos sox suns sur surf sus tata taxi tens term terms test tests
tex texts thats there these this tips toes tops torn tos town towns traps tree trees tres turn
turns urn urw us usa usr vary voor vos xerox
"""

private let contextSource = """
acs afro air ama ams ana ans aps ari arm arms ars arts as asc asi asm asn asp ast ats axis bans
bar bars bas basis bats bee beef been beer beers bees ber bets bis bits boo boost boots boris bos
bow buf burst bus bust cans caps car cars carts cast casts cats chair chaos char cheers chef chefs
cher chest chips cocos cor cows cups cur cuts dams dans days dee deer def der dis docs doo dorm
dos dow down eos eps esp gas gays goo hair hama hangs hans hast hats hee hero hers hes hist hits
honor hurts ifs ira irs keeps lama lamar laos lars las last lasts lawn lax lee lens lest lets
lifts lis loops lori los lost lots low lungs lust lux macs mais mama mars marx mas mast mats max
maxi maya mer mets mir mira mist mono moo moon mos moto motors must nes nest nets ngos nist noon
nuts oasis orf ors own owns per pharma quest raf rama rams rats ref rene rests rex roof roots rust
sans secs see seen ser sets sex sir songs soo sorts taj taps tar tas tax taxis tee tees ter tes
testers thee ther thor tis tits toast too toon toons tor tori tow trans trust trusts turf tyr ups
uri usc usps vans var vast vest vests vets virus vis visa visas vor vows vox xoops
"""
