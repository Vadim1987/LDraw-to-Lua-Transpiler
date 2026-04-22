-- ~Panel  1 x  2 x  1 without Front Face
-- Name: s\4865as01.dat
-- Author: James Jessiman
-- !LDRAW_ORG Subpart UPDATE 2020-03
-- !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

-- BFC CERTIFY CCW

-- !HISTORY 2003-07-03 [Steffen] BFCed, subfiled
-- !HISTORY 2004-04-22 [PTadmin] Official Update 2004-02
-- !HISTORY 2007-09-10 [PTadmin] Header formatted for
  -- Contributor Agreement
-- !HISTORY 2008-07-01 [PTadmin] Official Update 2008-01
-- !HISTORY 2020-07-14 [PTadmin] Renamed from s/4865s01
-- !HISTORY 2020-12-29 [PTadmin] Official Update 2020-03

ref(dat_stud3, 16, 0, 20, 0, 1, 0, 0, 0, -1, 0, 0, 0, 1)
-- BFC INVERTNEXT
ref(dat_box5, 16, 0, 24, 0, 16, 0, 0, 0, -4, 0, 0, 0, 6)
quad(16, 20, 24, 10, 16, 24, 6, -16, 24, 6, -20, 24, 10)
quad(16, -20, 24, 10, -16, 24, 6, -16, 24, -6, -20, 24, -10)
quad(16, -20, 24, -10, -16, 24, -6, 16, 24, -6, 20, 24, -10)
quad(16, 20, 24, -10, 16, 24, -6, 16, 24, 6, 20, 24, 10)
edge(20, 24, 10, -20, 24, 10)
edge(-20, 24, 10, -20, 24, -10)
edge(-20, 24, -10, 20, 24, -10)
edge(20, 24, -10, 20, 24, 10)
edge(20, 16, 6, -20, 16, 6)
edge(-20, 16, 6, -20, 16, -10)
edge(-20, 16, -10, 20, 16, -10)
edge(20, 16, -10, 20, 16, 6)
edge(20, 0, 10, -20, 0, 10)
edge(-20, 0, 10, -20, 0, 6)
edge(-20, 0, 6, 20, 0, 6)
edge(20, 0, 6, 20, 0, 10)
edge(20, 0, 6, 20, 16, 6)
edge(-20, 0, 6, -20, 16, 6)
edge(20, 16, -10, 20, 24, -10)
edge(-20, 16, -10, -20, 24, -10)
edge(20, 0, 10, 20, 24, 10)
edge(-20, 0, 10, -20, 24, 10)
quad(16, 20, 16, -10, 20, 16, 6, -20, 16, 6, -20, 16, -10)
quad(16, 20, 0, 6, 20, 0, 10, -20, 0, 10, -20, 0, 6)
quad(16, -20, 24, 10, -20, 24, -10, -20, 16, -10, -20, 16, 6)
quad(16, -20, 24, -10, 20, 24, -10, 20, 16, -10, -20, 16, -10)
quad(16, 20, 24, -10, 20, 24, 10, 20, 16, 6, 20, 16, -10)
quad(16, -20, 24, 10, -20, 16, 6, -20, 0, 6, -20, 0, 10)
quad(16, -20, 16, 6, 20, 16, 6, 20, 0, 6, -20, 0, 6)
quad(16, 20, 16, 6, 20, 24, 10, 20, 0, 10, 20, 0, 6)
--

