-- Box with 5 Faces and All Edges
-- Name: box5.dat
-- Author: James Jessiman
-- !LDRAW_ORG Primitive UPDATE 2012-01
-- !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

-- BFC CERTIFY CCW

-- !HISTORY 2002-04-03 [sbliss] Modified for BFC compliance
-- !HISTORY 2002-04-25 [PTadmin] Official Update 2002-02
-- !HISTORY 2007-06-24 [PTadmin] Header formatted for
  -- Contributor Agreement
-- !HISTORY 2008-07-01 [PTadmin] Official Update 2008-01
-- !HISTORY 2012-02-16 [Philo] Changed to CCW
-- !HISTORY 2012-03-30 [PTadmin] Official Update 2012-01

edge(1, 1, 1, -1, 1, 1)
edge(-1, 1, 1, -1, 1, -1)
edge(-1, 1, -1, 1, 1, -1)
edge(1, 1, -1, 1, 1, 1)
edge(1, 0, 1, -1, 0, 1)
edge(-1, 0, 1, -1, 0, -1)
edge(-1, 0, -1, 1, 0, -1)
edge(1, 0, -1, 1, 0, 1)
edge(1, 0, 1, 1, 1, 1)
edge(-1, 0, 1, -1, 1, 1)
edge(1, 0, -1, 1, 1, -1)
edge(-1, 0, -1, -1, 1, -1)
quad(16, -1, 1, 1, 1, 1, 1, 1, 1, -1, -1, 1, -1)
quad(16, -1, 1, 1, -1, 0, 1, 1, 0, 1, 1, 1, 1)
quad(16, -1, 1, -1, -1, 0, -1, -1, 0, 1, -1, 1, 1)
quad(16, 1, 1, -1, 1, 0, -1, -1, 0, -1, -1, 1, -1)
quad(16, 1, 1, 1, 1, 0, 1, 1, 0, -1, 1, 1, -1)

