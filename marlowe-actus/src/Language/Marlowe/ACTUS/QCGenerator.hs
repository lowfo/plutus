{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-incomplete-uni-patterns -fno-warn-name-shadowing -fno-warn-unused-do-bind #-}
module Language.Marlowe.ACTUS.QCGenerator where

import qualified Data.List                                         as L
import qualified Data.Map                                          as M
import           Data.Time
import           Data.Time.Clock.POSIX                             (posixSecondsToUTCTime)
import           Language.Marlowe.ACTUS.Analysis                   (genProjectedCashflows)
import           Language.Marlowe.ACTUS.Definitions.BusinessEvents (RiskFactors (..))
import           Language.Marlowe.ACTUS.Definitions.ContractTerms
import           Language.Marlowe.ACTUS.Definitions.Schedule
import           Test.QuickCheck

epochToDay :: Integer -> Day
epochToDay = utctDay . posixSecondsToUTCTime . fromIntegral

largeamount :: Gen Double
largeamount = choose (-1.0, 10000000.0)

smallamount :: Gen Double
smallamount = choose (-1.0, 1000.0)

percentage :: Gen Double
percentage = choose (-1.0, 100.0)

scalingFactor :: Gen Double
scalingFactor = choose (-1.0, 100.0)

mightbe :: Gen a -> Gen (Maybe a)
mightbe original = oneof [ Just <$> original, return Nothing ]

zeroOr :: Gen Double -> Gen Double
zeroOr original = oneof [return 0.0, original]

oneOr :: Gen Double -> Gen Double
oneOr original = oneof [return 1.0, original]

maxDate :: Integer
maxDate = 1607672749

secondsPerYear :: Integer
secondsPerYear = 31557600

date :: Gen Day
date = epochToDay <$> choose (0, maxDate)


cyclePeriodFreq :: Gen Period
cyclePeriodFreq = frequency [ (1, return P_D)
                            , (10, return P_W)
                            , (20, return P_M)
                            , (5, return P_Q)
                            , (5, return P_H)
                            , (70, return P_Y)
                            ]

datecycle :: Gen Cycle
datecycle = Cycle <$> sized (\n -> choose (0, maxDate `div` (toInteger n * secondsPerYear))) <*> cyclePeriodFreq <*> elements [ShortStub, LongStub]

contractTermsGen :: Gen ContractTerms
contractTermsGen = do
    contracttype <- elements [PAM]
    sd <- date
    ied <- date

    interest <- mightbe percentage
    notional <- mightbe largeamount
    pdied <- zeroOr smallamount

    feebasis <- elements [FEB_A, FEB_N]
    feerate <- zeroOr percentage

    penaltytype <- elements [PYTP_A , PYTP_N , PYTP_I , PYTP_O]
    penaltyrate <- zeroOr percentage
    cpyrt <- zeroOr percentage

    includeendday <- elements [True, False]
    eomc <- elements [EOMC_EOM, EOMC_SD]
    bdc <- elements [BDC_NULL, BDC_SCF, BDC_SCMF, BDC_CSF, BDC_CSMF, BDC_SCP, BDC_SCMP, BDC_CSP, BDC_CSMP]
    dcc <- elements [DCC_A_AISDA, DCC_A_360, DCC_A_365, DCC_E30_360ISDA, DCC_E30_360, DCC_B_252]
    pref <- elements [PREF_Y, PREF_N]
    cntrl <- elements [CR_BUY, CR_SEL]

    scef <- elements [SE_000, SE_0N0, SE_00M, SE_0NM, SE_I00, SE_IN0, SE_I0M, SE_INM]
    scixsd <- oneOr scalingFactor
    scied <- oneOr scalingFactor

    rrsp <- zeroOr percentage
    rrmlt <- oneOr scalingFactor
    rrpf <- zeroOr percentage
    rrpc <- oneOr percentage
    rrlc <- oneOr percentage
    rrlf <- zeroOr percentage

    nextPrincipalRedemption <- mightbe largeamount
    purchaseDate <- mightbe date
    maturityDate <- mightbe date
    terminationDate <- mightbe date
    priceAtTerminationDate <- mightbe smallamount
    priceAtPurchaseDate <- mightbe smallamount

    optionalityCycle <- mightbe datecycle
    optionalityAnchor <- mightbe date

    scalingCycle <- mightbe datecycle
    scalingAnchor <- mightbe date

    rateResetCycle <- mightbe datecycle
    rateResetAnchor <- mightbe date
    nextRateReset <- mightbe percentage

    interestCapitalisationDate <- mightbe date
    interestPaymentCycle <- mightbe datecycle
    interestPaymentAnchor <- mightbe date
    accruedInterest <- mightbe smallamount

    principalRedemptionCycle <- mightbe datecycle
    principalRedemptionAnchor <- mightbe date

    interestPaymentCalculationBase <- mightbe $ elements [IPCB_NT, IPCB_NTIED, IPCB_NTL]
    interestPaymentCalculationBaseAmount <- mightbe largeamount
    interestPaymentCalculationBaseCycle <- mightbe datecycle
    interestPaymentCalculationBaseAnchor <- mightbe date

    feeCycle <- mightbe datecycle
    feeAnchor <- mightbe date
    feeAccrued <- mightbe smallamount

    return ContractTerms {
        contractId     = "0"
        , contractType = Just contracttype
        , ct_IED       = ied
        , ct_SD        = sd
        , ct_MD        = maturityDate
        , ct_TD        = terminationDate
        , ct_PRNXT     = nextPrincipalRedemption
        , ct_PRD       = purchaseDate
        , ct_CNTRL     = cntrl
        , ct_PDIED     = pdied
        , ct_NT        = notional
        , ct_PPRD      = priceAtPurchaseDate
        , ct_PTD       = priceAtTerminationDate
        , ct_DCC       = dcc
        , ct_PREF      = pref
        , ct_PRF       = CS_PF
        , scfg         = ScheduleConfig {
            calendar = [] -- TODO
            , includeEndDay = includeendday
            , eomc = eomc
            , bdc = bdc
        }
        -- Penalties
        , ct_PYRT      = penaltyrate
        , ct_PYTP      = penaltytype
        , ct_cPYRT     = cpyrt
        -- Optionality
        , ct_OPCL      = optionalityCycle
        , ct_OPANX     = optionalityAnchor
        -- Scaling:
        , ct_SCIED     = scied
        , ct_SCEF      = scef
        , ct_SCCL      = scalingCycle
        , ct_SCANX     = scalingAnchor
        , ct_SCIXSD    = scixsd
        -- Rate Reset
        , ct_RRCL      = rateResetCycle
        , ct_RRANX     = rateResetAnchor
        , ct_RRNXT     = nextRateReset
        , ct_RRSP      = rrsp
        , ct_RRMLT     = rrmlt
        , ct_RRPF      = rrpf
        , ct_RRPC      = rrpc
        , ct_RRLC      = rrlc
        , ct_RRLF      = rrlf
        -- Interest
        , ct_IPCED     = interestCapitalisationDate
        , ct_IPCL      = interestPaymentCycle
        , ct_IPANX     = interestPaymentAnchor
        , ct_IPNR      = interest
        , ct_IPAC      = accruedInterest
        , ct_PRCL      = principalRedemptionCycle
        , ct_PRANX     = principalRedemptionAnchor
        , ct_IPCB      = interestPaymentCalculationBase
        , ct_IPCBA     = interestPaymentCalculationBaseAmount
        , ct_IPCBCL    = interestPaymentCalculationBaseCycle
        , ct_IPCBANX   = interestPaymentCalculationBaseAnchor
        -- Fee
        , ct_FECL      = feeCycle
        , ct_FEANX     = feeAnchor
        , ct_FEAC      = feeAccrued
        , ct_FEB       = feebasis
        , ct_FER       = feerate
        -- enable settlement currency
        , ct_CURS      = False
        , constraints  = Nothing
    }


riskAtTGen :: Gen RiskFactors
riskAtTGen = RiskFactors <$> percentage <*> percentage <*> percentage <*> smallamount

riskFactorsGen :: ContractTerms -> Gen (M.Map Day RiskFactors)
riskFactorsGen ct = do
    let days = cashCalculationDay <$> genProjectedCashflows ct
    rf <- vectorOf (L.length days) riskAtTGen
    return $ M.fromList $ L.zip days rf

riskFactorsGenRandomWalkGen :: ContractTerms -> Gen (M.Map Day RiskFactors)
riskFactorsGenRandomWalkGen contractTerms = do
    rfs <- riskFactorsGen contractTerms
    riskAtT <- riskAtTGen
    let
        (riskFactorsDates, riskFactorsValues) = unzip $ M.toList rfs

        fluctuate state fluctiation = state + (fluctiation - 50) / 100
        walk rf st =
            let fluctuate' extractor = fluctuate (extractor rf) (extractor st)
            in RiskFactors (fluctuate' o_rf_CURS) (fluctuate' o_rf_RRMO) (fluctuate' o_rf_SCMO) (fluctuate' pp_payoff)
        path = L.scanl walk riskAtT riskFactorsValues
    return $ M.fromList $ L.zip riskFactorsDates path
