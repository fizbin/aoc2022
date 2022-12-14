import Control.Applicative
import Control.Arrow (Arrow (first))
import Data.List (sortBy)
import Data.List.Split
import System.Environment (getArgs)

data ListIsh = Li Int | Lo [ListIsh] deriving (Show, Eq)

instance Read ListIsh where
    readsPrec _ s = (first Li <$> reads s) ++ (first Lo <$> readList s)

isOrder :: ListIsh -> ListIsh -> Maybe Bool
isOrder (Li x) (Li y) = case compare x y of
    LT -> Just True
    GT -> Just False
    EQ -> Nothing
isOrder (Lo []) (Lo []) = Nothing
isOrder (Lo []) (Lo _) = Just True
isOrder (Lo _) (Lo []) = Just False
isOrder (Lo (x : xx)) (Lo (y : yy)) = isOrder x y <|> isOrder (Lo xx) (Lo yy)
isOrder x@(Li _) y@(Lo _) = isOrder (Lo [x]) y
isOrder x@(Lo _) y@(Li _) = isOrder x (Lo [y])

cmpListIsh :: ListIsh -> ListIsh -> Ordering
cmpListIsh x y = case isOrder x y of
    Just True -> LT
    Just False -> GT
    Nothing -> EQ

main :: IO ()
main = do
    args <- getArgs
    let filename =
            if null args
                then "aoc13.in"
                else head args
    s <- lines <$> readFile filename
    let spairs = splitWhen null s
    let spairs' = map (map read) spairs :: [[ListIsh]]
    let isum = sum :: [Int] -> Int
    print $ isum $ map fst $ filter ((== Just True) . (\[x, y] -> isOrder x y) . snd) $ zip [1 ..] spairs'
    let fullthing = read "[[2]]" : read "[[6]]" : map read (filter (not . null) s) :: [ListIsh]
    let fullSorted = sortBy cmpListIsh fullthing
    let magicI :: [Int]
        magicI = map fst $ filter (\x -> snd x == read "[[2]]" || snd x == read "[[6]]") $ zip [1 ..] fullSorted
    print $ product magicI
