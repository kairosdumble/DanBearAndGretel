const pool = require("../db/pool");

async function updateTotal(reservationId, { fare }) {
    const client = await pool.connect();
    try{
        await client.query(`
            UPDATE payments 
            SET fare = $1 
            WHERE reservation_id = $2
        `, [fare, reservationId]);
        
        await client.query("COMMIT");
    }catch(err){
        await client.query("ROLLBACK");
        throw err;
    }finally{
        client.release();
    }
}

module.exports = { updateTotal };