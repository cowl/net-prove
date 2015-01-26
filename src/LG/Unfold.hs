module LG.Unfold where
import LG.Graph
import qualified Lexicon as Lexicon
import qualified Data.Map as Map

-- 'unfold' will maximally unfold every given formula and add all generated formulae to a new composition graph.
-- Operator-specific rules are applied to create a link connecting the formula with its sub-formulae.
-- For every node generated, a twin node is created an connected to the original node through an axioma link. (See M&M, p. 23: Definition 3.2; bullet 1)
-- The process is repeated on these twin nodes until we have created nodes for atomic formulae.
-- See Moortgat & Moot (2012), p. 6-7 for unfolding on proof structures without terms, and p. 24 for their term-annotated counterparts. This function add terms to the nodes.
-- The terms generated by this module are guaranteed to be unique in the composition graph, because they are based on their node identifiers.
unfold :: [Lexicon.Entry] -> [Lexicon.Entry] -> CompositionGraph
unfold hypotheses conclusions = graph
  where
    (hypothesisNodes, idCounter1) = unfoldHypotheses  hypotheses  0          []
    (conclusionNodes, idCounter2) = unfoldConclusions conclusions idCounter1 []
    graph = insertNodes (hypothesisNodes ++ conclusionNodes) Map.empty

---------------------
--- UNFOLD HYPOTHESIS
---------------------

-- Wrapper functions
unfoldHypotheses []     idCounter acc = (acc, idCounter)
unfoldHypotheses (x:xs) idCounter acc = unfoldHypotheses xs newCount (unfoldedNodes++acc)
  where (_, unfoldedNodes, newCount) = unfoldHypothesis x idCounter

unfoldHypothesis lexEntry idCounter = unfoldHypothesis' (Lexicon.formula lexEntry) (Lexicon.term lexEntry) Nothing idCounter

-- unfoldHypothesis' first creates a copy of the given formula and connects the original and the copy to each other through an axioma link. After that, it will see whether it can do an unfolding, based on whether the formula is complex and so has an operator link associated with it. (See M&M, p. 24 for a list of the links.)
unfoldHypothesis' f defaultTerm l idCounter = (firstId, nodes++aNodes++bNodes, bCount)
    where -- Common to all unfoldings: first create an axioma link
          firstId  = idCounter+0
          mainId   = idCounter+1
          newCount = idCounter+2
          axLink   = Just ((Active firstId) :|: (Active mainId))
          nodes    = [firstId:@ (Node f defaultTerm axLink l),
                      mainId :@ (Node f unfoldTerm  operatorLink axLink)]
          -- Formula-specific unfold info
          (unfoldTerm, operatorLink, aNodes, bNodes, bCount) = getUnfoldInfoH f mainId newCount

-- Atoms: terminal nodes when unfolding
getUnfoldInfoH f@(P (AtomP _)) mainId newCount = (Va (Variable   (show mainId)), Nothing, [], [], newCount)
getUnfoldInfoH f@(N (AtomN _)) mainId newCount = (Ev (Covariable (show mainId)), Nothing, [], [], newCount)

-- L/
getUnfoldInfoH f@(N (b:/:a)) mainId newCount = (term, operatorLink, aNodes, bNodes, bCount)
    where term     = Ev (E' bVar :/ V' aVar)
          aVar     = Variable (show aId)
          bVar     = Covariable (show bId)
          aTerm    = (Va aVar)
          bTerm    = (Ev bVar)
          link = [MainT (mainId), Active aId]
                             :○:
                        [Active bId]
          operatorLink = Just link
          (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink newCount
          (bId, bNodes, bCount) = unfoldHypothesis' b bTerm operatorLink aCount
-- L
getUnfoldInfoH f@(P (a :<×>: b)) mainId idCount = (mainTerm, operatorLink, aNodes, bNodes, bCount)
  where mainTerm     = (Va (Variable (show mainId)))
        aTerm = (Va (Variable (show aId)))
        bTerm = (Va (Variable (show bId)))
        link         =      [MainT (mainId)]
                                     :●:
                           [Active aId, Active bId]
        operatorLink = Just link
        (aId, aNodes, aCount) = unfoldHypothesis' a aTerm operatorLink idCount
        (bId, bNodes, bCount) = unfoldHypothesis' b bTerm operatorLink aCount

-- L\
getUnfoldInfoH f@(N (a :\: b)) mainId idCount = (mainTerm, operatorLink, aNodes, bNodes, bCount)
  where
    mainTerm = Ev ((V' aVar) :\ (E' bVar))
    aVar = (Variable   (show aId))
    bVar = (Covariable (show bId))
    link        = [Active aId, MainT (mainId)]
                               :○:
                          [Active bId]
    operatorLink = Just link
    (aId, aNodes, aCount) = unfoldConclusion' a (Va aVar) operatorLink idCount
    (bId, bNodes, bCount) = unfoldHypothesis' b (Ev bVar) operatorLink aCount

-- L⊘
getUnfoldInfoH mainFormula@(P (b :</>: a)) mainId idCount = (mainTerm, operatorLink, aNodes, bNodes, bCount)
  where
    -- Node terms, based on their node ids
    mainTerm = Ev (Covariable (show mainId))
    aTerm = Va (Variable   (show aId))
    bTerm = Ev (Covariable (show bId))
    -- Operator link
    link = [MainT (mainId), Active aId]
                         :●:
                     [Active bId]
    operatorLink = Just link
    (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink idCount
    (bId, bNodes, bCount) = unfoldHypothesis' b bTerm operatorLink aCount

-- L⊕
getUnfoldInfoH mainFormula@(N (a :<+>: b)) mainId idCount = (mainTerm, operatorLink, aNodes, bNodes, bCount)
  where 
    mainTerm = Ev (E' aVar :<+> E' bVar)
    aVar = (Covariable (show aId))
    bVar = (Covariable (show bId))
    aTerm = Ev aVar
    bTerm = Ev bVar
    -- Operator link
    link         =      [MainT (mainId)]
                               :○:
                     [Active aId, Active bId]
    operatorLink = Just link
    (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink idCount
    (bId, bNodes, bCount) = unfoldHypothesis' b bTerm operatorLink aCount

-- L<\>
getUnfoldInfoH mainFormula@(P (a :<\>: b)) mainId idCount = (mainTerm, operatorLink, aNodes, bNodes, bCount)
  where
    -- Node terms, based on their node ids
    mainTerm = Va (E' aVar :<\> V' bVar)
    aVar = (Covariable (show aId))
    bVar = (Variable   (show bId))
    aTerm = Ev aVar
    bTerm = Va bVar
    -- Operator link
    link         = [Active aId, MainT (mainId)]
                               :●:
                           [Active bId]
    operatorLink = Just link
    (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink idCount
    (bId, bNodes, bCount) = unfoldHypothesis' b bTerm operatorLink aCount

---------------------
--- UNFOLD CONCLUSION
---------------------
unfoldConclusions []     idCounter acc = (acc, idCounter)
unfoldConclusions (x:xs) idCounter acc = unfoldConclusions xs newCount (unfoldedNodes++acc)
  where (_, unfoldedNodes, newCount) = unfoldConclusion x idCounter

unfoldConclusion lexEntry idCounter = unfoldConclusion' (Lexicon.formula lexEntry) (Lexicon.term lexEntry) Nothing idCounter

unfoldConclusion' f defaultTerm l idCounter = (firstId, nodes++aNodes++bNodes, bCount)
    where -- Common to all unfoldings: first create an axioma link
          firstId  = idCounter+0
          mainId   = idCounter+1
          newCount = idCounter+2
          axLink   = Just ((Active mainId) :|: (Active firstId))
          nodes    = [firstId:@ (Node f defaultTerm l axLink),
                      mainId :@ (Node f unfoldTerm  axLink operatorLink)]
          -- Formula-specific unfold info
          (unfoldTerm, operatorLink, aNodes, bNodes, bCount) = getUnfoldInfoC f mainId newCount

-- Atoms: terminal nodes for unfolding
getUnfoldInfoC f@(P (AtomP _)) mainId idCount = (Va (Variable   (show mainId)), Nothing, [], [], idCount)
getUnfoldInfoC f@(N (AtomN _)) mainId idCount = (Ev (Covariable (show mainId)), Nothing, [], [], idCount)

-- R/
getUnfoldInfoC f@(N (b:/:a)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Ev (E' bVar :/ V' aVar)
          aVar     = Variable   (show aId)
          bVar     = Covariable (show bId)
          aTerm    = Va aVar
          bTerm    = Ev bVar
          -- Operator link
          link     =      [Active bId]
                               :●:
                    [MainT (mainId), Active aId]
          operatorLink = Just link
          (bId, bNodes, bCount) = unfoldConclusion' b bTerm operatorLink aCount
          (aId, aNodes, aCount) = unfoldHypothesis' a aTerm operatorLink (idCounter+2)

-- R⊗
getUnfoldInfoC f@(P (b:<×>:a)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Va (V' aVar :<×> V' bVar)
          aVar     = Variable (show aId)
          bVar     = Variable (show bId)
          aTerm    = Va aVar
          bTerm :: NodeTerm
          bTerm    = Va bVar
          -- Operator link
          link     =[Active aId, Active bId]
                               :○:
                          [MainT (mainId)]
          operatorLink = Just link
          (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink (idCounter+2)
          (bId, bNodes, bCount) = unfoldConclusion' b bTerm operatorLink aCount

-- R\
getUnfoldInfoC f@(N (b:\:a)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Ev (E' bVar :/ V'  aVar)
          aVar     = Variable   (show aId)
          bVar     = Covariable (show bId)
          aTerm    = Va aVar
          bTerm    = Ev bVar
          -- Operator link
          link     =      [Active bId]
                               :●:
                    [Active aId, MainT (mainId)]
          operatorLink = Just link
          (aId, aNodes, aCount) = unfoldHypothesis' a (Va aVar) operatorLink (idCounter+2)
          (bId, bNodes, bCount) = unfoldConclusion' b (Ev bVar) operatorLink aCount

-- R⊘
getUnfoldInfoC f@(P (b:</>:a)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Va (V' bVar :</> E' aVar)
          aVar     = Covariable (show aId)
          bVar     = Variable   (show bId)
          aTerm    = Ev aVar
          bTerm    = Va bVar
          -- Operator link
          operatorLink = Just ([Active bId]
                                   :○:
                        [MainT (mainId), Active aId])
          (aId, aNodes, aCount) = unfoldHypothesis' a aTerm operatorLink (idCounter+2)
          (bId, bNodes, bCount) = unfoldConclusion' b bTerm operatorLink aCount

-- R⊕
getUnfoldInfoC f@(N (a:<+>:b)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Ev (E' bVar :<+> E' aVar)
          aVar     = Covariable (show aId)
          bVar     = Covariable (show bId)
          aTerm    = Ev aVar
          bTerm    = Ev bVar
          -- Operator link
          operatorLink = Just ([Active aId, Active bId]
                                   :●:
                             [MainT (mainId)])
          (aId, aNodes, aCount) = unfoldConclusion' a aTerm operatorLink (idCounter+2)
          (bId, bNodes, bCount) = unfoldConclusion' b bTerm operatorLink aCount

-- R<\>
getUnfoldInfoC f@(P (a:<\>:b)) mainId idCounter = (mainTerm, operatorLink, aNodes, bNodes, bCount)
    where firstId  = idCounter+0
          mainId   = idCounter+1
          -- Terms, derived from node ids
          mainTerm = Va (E' aVar :<\>V' bVar)
          aVar     = Covariable (show aId)
          bVar     = Variable   (show bId)
          aTerm    = Ev aVar
          bTerm    = Va bVar
          -- Operator link
          operatorLink = Just ([Active bId]
                                   :○:
                        [Active aId, MainT (mainId)])
          (aId, aNodes, aCount) = unfoldHypothesis' a aTerm operatorLink (idCounter+2)
          (bId, bNodes, bCount) = unfoldConclusion' b bTerm operatorLink aCount