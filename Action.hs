{-# LANGUAGE DeriveFunctor #-}

import           Control.Monad (ap, liftM)
import           Control.Monad.Trans.Writer (execWriter, tell)

data Chain f a
  = Seg (f (Chain f a))
  | End a

instance Functor f => Functor (Chain f) where
  fmap = liftM

instance Functor f => Applicative (Chain f) where
  pure = End
  (<*>) = ap

instance Functor f => Monad (Chain f) where
  Seg s >>= f = Seg $ (f =<<) <$> s
  End a >>= f = f a

seg :: ((a -> Chain f a) -> f (Chain f a)) -> Chain f a
seg = Seg . ($ End)

mapChain :: Functor f' => (f (Chain f a) -> f' (Chain f a)) -> Chain f a -> Chain f' a
mapChain f (Seg s) = Seg $ mapChain f <$> f s
mapChain _ (End a) = End a

runChain :: Monad f => Chain f a -> f a
runChain (Seg s) = runChain =<< s
runChain (End a) = pure a


data GenF o i c = GenF o (i -> c)
  deriving (Functor)

runGen :: Functor m => (o -> m i) -> GenF o i c -> m c
runGen f (GenF o c) = c <$> f o

type Gen o i = Chain (GenF o i)

yield :: o -> Gen o i i
yield = seg . GenF

each :: Monad m => (o -> m i) -> Gen o i a -> m a
each f = runChain . mapChain (runGen f)

list :: Gen o () a -> [o]
list = ($ []) . execWriter . each (tell . (:))

fib :: Int -> Int -> Gen Int i ()
fib a b = yield a *> fib b (a + b)


data RwF c
  = GetLn (String -> c)
  | PutStrLn String c
  deriving (Functor)

runRw :: RwF c -> IO c
runRw (GetLn c)      = c <$> getLine
runRw (PutStrLn s c) = c <$ putStrLn s

type Rw = Chain RwF

rwGetLn :: Rw String
rwGetLn = seg GetLn

rwPutStrLn :: String -> Rw ()
rwPutStrLn ln = seg $ PutStrLn ln . ($ ())

echo :: Rw ()
echo = rwPutStrLn =<< rwGetLn


main :: IO ()
main = do
  print . take 10 . list $ fib 0 1
  runChain $ mapChain runRw echo

-- like Generator.hs, but ensure correct output/input type pairs
