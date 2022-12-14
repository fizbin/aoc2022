{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TupleSections #-}
{-# OPTIONS_GHC -Wall #-}

import Control.Monad (join)
import Data.Char (isSpace)
import Data.List
import Data.List.Split (splitWhen)
import qualified Data.Map as M
import Data.Maybe (isJust)
import System.Environment (getArgs)

-- import Debug.Trace (trace)

type C3 a = (a, a, a)

class VecOps x where
    -- | Vector addition
    ($+$) :: x -> x -> x

    -- | Scalar multiplication
    iMul :: Int -> x -> x

instance (Num a, Num b, Num c) => VecOps (a, b, c) where
    (a, b, c) $+$ (a', b', c') = (a + a', b + b', c + c')
    iMul x (a, b, c) = (fromIntegral x * a, fromIntegral x * b, fromIntegral x * c)

instance (Num a, Num b) => VecOps (a, b) where
    (a, b) $+$ (a', b') = (a + a', b + b')
    iMul x (a, b) = (fromIntegral x * a, fromIntegral x * b)

infixl 6 $+$

-- | Vector cross product
($*$) :: Num a => C3 a -> C3 a -> C3 a
(a, b, c) $*$ (a', b', c') = (b * c' - c * b', c * a' - a * c', a * b' - b * a')

infixl 7 $*$

flatland :: C3 a -> (a, a)
flatland (a, b, _) = (a, b)

-- | Parses into (Left False) for "L", (Left True) for "R", or (Right dist) for "walk dist"
parseLine :: String -> [Either Bool Int]
parseLine ('L' : s) = Left False : parseLine s
parseLine ('R' : s) = Left True : parseLine s
parseLine [] = []
parseLine (w : s) | isSpace w = parseLine s
parseLine s = case reads s of
    (r, s') : _ -> Right r : parseLine s'
    [] -> error $ "Out of parses " ++ show s

part1 :: M.Map (Int, Int) Char -> [Either Bool Int] -> (Int, Int, Int)
part1 grid directions =
    let initialspot = (\(a, b) -> (a, b, 0)) . fst $ M.findMin grid
        initialdir = (0, 1, 0)
        (finalspot, finaldir) = foldl' (flip go) (initialspot, initialdir) directions
        (row, col, _) = finalspot
        fdir = case finaldir of
            (0, 1, 0) -> 0
            (1, 0, 0) -> 1
            (0, -1, 0) -> 2
            (-1, 0, 0) -> 3
            x -> error $ "Bad final dir " ++ show x
     in (row + 1, col + 1, fdir)
  where
    go (Left True) (spot, dir) = (spot, dir $*$ (0, 0, 1))
    go (Left False) (spot, dir) = (spot, (0, 0, 1) $*$ dir)
    go (Right dist) (spot, dir) = go' dist spot dir
    go' 0 spot dir = (spot, dir)
    go' dist spot dir =
        let nxtspot = nextSpot spot dir
         in case M.lookup (flatland nxtspot) grid of
                Just '#' -> (spot, dir)
                Just '.' -> go' (dist - 1) nxtspot dir
                sth -> error $ "Bad lookup: " ++ show sth
    nextSpot spot dir =
        let base = spot $+$ dir
            back = (\(a, b, c) (a', b', c') -> (a - 300 * a', b - 300 * b', c - 300 * c')) spot dir
         in if isJust (M.lookup (flatland base) grid)
                then base
                else head $ filter (isJust . (`M.lookup` grid) . flatland) $ iterate ($+$ dir) back

data Face = Face
    { localX :: C3 Int
    , localY :: C3 Int
    , localZ :: C3 Int
    , spaceStart :: C3 Int
    , gridStart :: (Int, Int)
    }
    deriving (Show, Eq)

part2 :: M.Map (Int, Int) Char -> [Either Bool Int] -> (Int, Int, Int)
part2 grid directions =
    let ((finalLZ, finalspot), finaldir) = foldl' (flip go) (((0, 0, 1), (0, 0, 0)), (0, 1, 0)) directions
        (row, col, face) = fst $ spaceMap M.! (finalLZ, finalspot)
        fdir
            | finaldir == localY face = 0
            | finaldir == localX face = 1
            | finaldir == (-1) `iMul` localY face = 2
            | finaldir == (-1) `iMul` localX face = 3
            | otherwise = error ("Bad final dir: " ++ show finaldir ++ " on " ++ show face)
     in (row + 1, col + 1, fdir)
  where
    gridsize = floor (sqrt (fromIntegral $ M.size grid `div` 6) :: Double)
    -- the top-left corners of each face when folded flat
    gridstarts = sort $ filter (\(a, b) -> a `mod` gridsize == 0 && b `mod` gridsize == 0) $ M.keys grid
    startFace = Face (1, 0, 0) (0, 1, 0) (0, 0, 1) (0, 0, 0) (minimum gridstarts) :: Face
    getFaces :: [Face] -> [Face]
    getFaces sofar =
        let sofarStarts = sort $ gridStart <$> sofar
            remaining = filter (`notElem` sofarStarts) gridstarts
            candidateUp = ((-1, 0),) <$> filter ((`elem` remaining) . ($+$ (-gridsize, 0)) . gridStart) sofar
            candidateDn = ((1, 0),) <$> filter ((`elem` remaining) . ($+$ (gridsize, 0)) . gridStart) sofar
            candidateLt = ((0, -1),) <$> filter ((`elem` remaining) . ($+$ (0, -gridsize)) . gridStart) sofar
            candidateRt = ((0, 1),) <$> filter ((`elem` remaining) . ($+$ (0, gridsize)) . gridStart) sofar
            candidates = candidateUp ++ candidateDn ++ candidateLt ++ candidateRt
            newFace ((xdir, ydir), face) =
                -- we leave face going (xdir, ydir); what face do we end up on?
                let (newLX, newLY, newLZ) = case (xdir, ydir) of
                        (0, _) ->
                            let nx = localX face
                                nz = ydir `iMul` localY face
                             in (nx, nz $*$ nx, nz)
                        (_, 0) ->
                            let ny = localY face
                                nz = xdir `iMul` localX face
                             in (ny $*$ nz, ny, nz)
                        _ -> error "Internal error"
                    newSpaceStart =
                        if xdir + ydir > 0
                            then spaceStart face $+$ (gridsize - 1) `iMul` newLZ
                            else spaceStart face $+$ (-(gridsize - 1)) `iMul` localZ face
                 in Face newLX newLY newLZ newSpaceStart (gridStart face $+$ (gridsize * xdir, gridsize * ydir))
         in case candidates of
                [] -> sofar
                _ -> getFaces $ nub (map newFace candidates ++ sofar)
    faces = getFaces [startFace]
    -- maps (local Z axis, spot-in-space) to (spot-on-grid, face, char)
    spaceMap :: M.Map (C3 Int, C3 Int) ((Int, Int, Face), Char)
    spaceMap = M.fromList $ flip concatMap faces $ \face ->
        [ ( (localZ face, spaceStart face $+$ r `iMul` localX face $+$ c `iMul` localY face)
          , ((r', c', face), grid M.! (r', c'))
          )
        | r <- [0 .. gridsize - 1]
        , c <- [0 .. gridsize - 1]
        , let (r', c') = (r, c) $+$ gridStart face
        ]
    -- (local Z axis, spot-i-space) -> space dir -> ((new local Z axis, new spot-in-space), new space dir)
    nxtSpotDir :: (C3 Int, C3 Int) -> C3 Int -> ((C3 Int, C3 Int), C3 Int)
    nxtSpotDir (myLZ, spot) dir =
        let naive = spot $+$ dir
         in if isJust (M.lookup (myLZ, naive) spaceMap)
                then ((myLZ, naive), dir)
                else ((dir, spot), (-1) `iMul` myLZ)
    go (Left True) ((myLZ, spot), dir) = ((myLZ, spot), dir $*$ myLZ)
    go (Left False) ((myLZ, spot), dir) = ((myLZ, spot), myLZ $*$ dir)
    go (Right dist) (spot, dir) = go' dist spot dir
    go' 0 spot dir = (spot, dir)
    go' dist (myLZ, spot) dir =
        let ((nLZ, nspot), ndir) = nxtSpotDir (myLZ, spot) dir
         in case M.lookup (nLZ, nspot) spaceMap of
                Just (_, '#') -> ((myLZ, spot), dir)
                Just (_, '.') -> go' (dist - 1) (nLZ, nspot) ndir
                sth -> error $ "Bad lookup: " ++ show sth ++ " for " ++ show (nLZ, nspot) ++ " from " ++ show ((myLZ, spot), dir)

main :: IO ()
main = do
    args <- getArgs
    let filename =
            if null args
                then "aoc22.in"
                else head args
    s <- lines <$> readFile filename
    let [grid, directionStr] = splitWhen null s
    let directions = parseLine $ join directionStr
    let gridMap :: M.Map (Int, Int) Char
        gridMap =
            M.fromList $
                map (\(r, (c, d)) -> ((r, c), d)) $
                    filter (\(_, (_, c)) -> not (isSpace c)) $
                        join $
                            zipWith (map . (,)) [0 ..] $
                                map (zip [0 ..]) grid
    let (p1row, p1col, p1dir) = part1 gridMap directions
    -- print (p1row, p1col, p1dir)
    print $ 1000 * p1row + 4 * p1col + p1dir
    let (p2row, p2col, p2dir) = part2 gridMap directions
    -- print (p2row, p2col, p2dir)
    print $ 1000 * p2row + 4 * p2col + p2dir
